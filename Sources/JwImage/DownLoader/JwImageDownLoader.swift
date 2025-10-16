//
//  JwImageDownLoader.swift
//  JwImage
//
//  Created by heojiwoo on 10/15/25.
//

import Foundation

/// URL 기반 이미지 다운로드를 담당하는 actor 클래스
/// - Thread-safe 하게 다운로드 요청을 직렬화 처리
/// - 동일 URL 요청 시 Task를 공유하여 중복 다운로드 방지
/// - 다운로드 완료 시 캐시에 저장하여 재사용
public final actor JwImageDownloader: JwImageDownloadable {
    public static let shared = JwImageDownloader()
    private init() {}
    
    private enum DownloadEntry {
        case inProgress(Task<JwImageData, Error>)
        case complete(JwImageData)
    }
    private var cache: [URL: DownloadEntry] = [:]

    /// URL을 이용해 이미지를 비동기로 다운로드합니다.
    ///
    /// 동일한 URL로 중복 요청이 들어온 경우,
    /// 이미 진행 중인 다운로드 Task를 재사용하여 불필요한 네트워크 호출을 방지합니다.
    /// 다운로드가 완료되면 결과(`JwImageData`)를 캐싱하여 다음 요청 시 즉시 반환합니다.
    ///
    /// 또한 `ETag`를 지원하여 서버 리소스가 변경되지 않은 경우
    /// 네트워크 비용을 최소화하도록 설계되었습니다.
    ///
    /// - Parameters:
    ///   - url: 다운로드할 이미지의 URL
    ///   - etag: 이전 다운로드 시 서버에서 받은 ETag 값 (선택적)
    /// - Returns: 다운로드된 이미지 데이터(`JwImageData`)
    /// - Throws:
    ///   - `JwDownloaderError.notChangedETag`: 서버 리소스가 변경되지 않아 304 응답을 받은 경우
    ///   - `JwDownloaderError.downloadImageError`: 이미지 다운로드 실패 시
    ///   - `JwDownloaderError.apiError`: 서버 응답이 유효하지 않은 경우
    ///
    /// ## 동작 방식
    /// 1. 동일한 URL의 Task가 이미 존재하면, 해당 Task의 결과를 기다림 (`await task.value`)
    /// 2. 없을 경우, 새 Task를 생성하여 다운로드 수행
    /// 3. 다운로드 완료 시 결과를 캐시에 저장 (`.complete`)
    /// 4. 실패 시 캐시에서 제거 후 에러 전달
    public func downloadImage(from url: URL, etag: String? = nil) async throws -> JwImageData {
        if let entry = cache[url] {
            switch entry {
            case .inProgress(let task): return try await task.value
            case .complete(let data):   return data
            }
        }

        let task = Task {
            try await self.download(from: url, etag: etag)
        }
        
        cache[url] = .inProgress(task)

        do {
            let data = try await task.value
            cache[url] = .complete(data)
            return data
        } catch {
            cache[url] = nil
            throw error
        }
    }

    /// URL 이미지 다운로드 취소
    /// - Parameter url: 취소할 이미지 URL
    /// - Note:
    ///   - 진행 중인 Task만 취소되며,
    ///     완료된 캐시는 그대로 유지.
    ///   - 중복 다운로드 방지 목적.
    public func cancelDownloadImage(url: URL) async {
        guard let cached = cache[url] else { return }
        
        switch cached {
        case .inProgress(let task):
            if !task.isCancelled {
                task.cancel()
            }
        case .complete:
            break
        }
    }
    
    // URL 이미지 다운로드
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - etag: 이미지 ETag
    /// - Returns: 이미지 다운로드 결과
    /// ## ETag 동작 요약
    /// 1. 요청 시 `If-None-Match` 헤더에 이전 ETag를 함께 전송.
    /// 2. 서버가 ETag 비교 후:
    ///     - 변경 없음 → 304 Not Modified 응답
    ///     - 변경됨 → 200 OK + 새 ETag + 새 데이터 반환.
    /// 3. 304 응답일 경우 기존 캐시를 그대로 사용.
    private func download(from url: URL, etag: String? = nil) async throws -> JwImageData {
        var request = URLRequest(url: url)
        
        if let etag = etag {
            request.addValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JwDownloaderError.apiError
        }

        switch http.statusCode {
        case 200..<300:
            let newETag = http.value(forHTTPHeaderField: "ETag")
            return JwImageData(data: data, etag: newETag)
        case 304:
            throw JwDownloaderError.notChangedETag
        default:
            throw JwDownloaderError.downloadImageError
        }
    }
}
