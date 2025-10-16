//
//  JwImageCache.swift
//  JwImage
//
//  Created by heojiwoo on 2025/10/16.
//

import Foundation
import UIKit
import Combine

/// 이미지 캐시 데이터 구조체
public struct JwImageData: Codable, Sendable {
    /// 이미지 원본 데이터
    public var data: Data
    /// ETag (선택)
    public var etag: String?
    
    public init(data: Data, etag: String? = nil) {
        self.data = data
        self.etag = etag
    }
}

/// 이미지 캐싱을 위한 싱글톤 클래스
/// - 메모리 캐시, 디스크 캐시를 이용해 캐시 진행
public class JwImageCache: @unchecked Sendable {
    
    // MARK: - Types
    public typealias ImageCacheItem = JwCacheItem<JwImageData>
    public typealias MemoryCache = JwMemoryCache<NSString, ImageCacheItem>
    public typealias DiskCache = JwDiskCache<NSString, ImageCacheItem>
    
    // MARK: - Singleton
    @MainActor public static let shared = JwImageCache()
    
    // MARK: - Cache Type
    public enum CacheType {
        case memory, disk
        
        static func defaultMemoryCache() -> JwMemoryCache<NSString, ImageCacheItem> {
            .init()
        }
        static func defaultDiskCache() -> JwDiskCache<NSString, ImageCacheItem> {
            .init()
        }
    }
    
    // MARK: - Properties
    /// 메모리 캐시
    private var memoryCache: MemoryCache = CacheType.defaultMemoryCache()
    /// 메모리 캐시 만료 시간
    private(set) var memoryCacheItemExpiredTime: JwCacheExpiration = .minutes(30)
    /// 메모리 캐시 만료 시간 측정 기준
    private(set) var memoryCacheItemStandardExpiration: JwCacheExpirationStandard = .create
    /// 만료된 메모리 캐시 정리 주기
    private(set) var cleanMemoryCacheExpiredTime: JwCacheExpiration = .minutes(30)
    
    /// 디스크 캐시
    private var diskCache: DiskCache = CacheType.defaultDiskCache()
    /// 디스크 캐시 만료 시간
    private(set) var diskCacheItemExpiredTime: JwCacheExpiration = .days(7)
    /// 디스크 캐시 만료 시간 측정 기준
    private(set) var diskCacheItemStandardExpiration: JwCacheExpirationStandard = .create
    /// 만료된 디스크 캐시 정리 주기
    private(set) var cleanDiskCacheExpiredTime: JwCacheExpiration = .days(7)
    
    private var cleanCacheTask: Task<Void, Never>?
    
    // MARK: - Init
    private init() {
        Task {
            startCleanCacheTimer()
        }
    }
    
    // MARK: - Get Image
    /// 캐시를 이용해 이미지 데이터 반환
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - cacheMemoryOnly: 메모리 캐시만 사용할지 여부
    /// - Returns: 캐시된 이미지 데이터
    public func getImageWithCache(url: URL, options: Set<JwOption>) async -> JwImageData? {
        let key = url.absoluteString

        // 메모리 캐시 확인
        if let memoryCacheData = memoryCache.getCache(key: NSString(string: key)) {
            return memoryCacheData.data
        }

        // 2 디스크 캐시 확인
        if !options.contains(.cacheMemoryOnly),
           var diskCacheData = diskCache.getCache(key: NSString(string: key)) {

            // 2-1 ETag 옵션 (optional)
            if !options.contains(.disableETag),
               let etag = diskCacheData.data.etag {
                do {
                    let newData = try await JwImageDownloader.shared.downloadImage(from: url, etag: etag)
                    diskCacheData.data = newData
                    saveDiskCache(key: key, data: newData)
                } catch JwDownloaderError.notChangedETag {
                    print("[JwImageCache] Disk Cache - Same Data (304)")
                } catch {
                    print("⚠️ [JwImageCache] ETag check failed: \(error)")
                }
            }
            saveMemoryCache(key: key, data: diskCacheData.data)
            return diskCacheData.data
        }

        // 3 캐시에서 전혀 못 찾으면
        guard !options.contains(.onlyFromCache) else { return nil }

        // 4 네트워크 다운로드
        guard let newImageData = try? await JwImageDownloader.shared.downloadImage(from: url) else {
            return nil
        }

        saveImageData(url: url.absoluteString, imageData: newImageData, options: options)
        return newImageData
    }
    
    // MARK: - Save Image
    /// 캐시에 이미지 데이터 저장
    /// - Parameters:
    ///   - url: Key로 사용될 이미지 URL
    ///   - imageData: 저장할 이미지 데이터
    public func saveImageData(
        url: String,
        imageData: JwImageData,
        options: Set<JwOption>? = nil
    ) {
        saveMemoryCache(key: url, data: imageData)
        if let options = options {
            if !options.contains(.cacheMemoryOnly) {
                saveDiskCache(key: url, data: imageData)
            }
        }
    }
    
    // MARK: - Configuration
    /// 메모리 캐시 교체
    /// - Parameter new: 새로운 메모리 캐시 인스턴스
    public func changeMemoryCache(_ new: MemoryCache) {
        memoryCache = new
    }
    
    /// 디스크 캐시 교체
    /// - Parameter new: 새로운 디스크 캐시 인스턴스
    public func changeDiskCache(_ new: DiskCache) {
        diskCache = new
    }
    
    /// 캐시 아이템의 만료 시간 설정
    /// - Parameters:
    ///   - cacheExpiredTime: 만료 시간
    ///   - cacheType: 업데이트할 캐시 타입
    public func updateCacheItemExpiredTime(
        _ cacheExpiredTime: JwCacheExpiration,
        cacheType: CacheType
    ) {
        switch cacheType {
        case .memory:
            self.memoryCacheItemExpiredTime = cacheExpiredTime
        case .disk:
            self.diskCacheItemExpiredTime = cacheExpiredTime
        }
    }
    
    /// 캐시 아이템의 만료 시간 측정 기준 설정
    /// - Parameters:
    ///   - standardExpiration: 만료 시간 측정 기준
    ///   - cacheType: 업데이트할 캐시 타입
    public func updateCacheItemStandardExpiration(
        _ standardExpiration: JwCacheExpirationStandard,
        cacheType: CacheType
    ) {
        switch cacheType {
        case .memory:
            self.memoryCacheItemStandardExpiration = standardExpiration
        case .disk:
            self.diskCacheItemStandardExpiration = standardExpiration
        }
    }
    
    /// 주기적인 캐시 정리 시간 설정
    /// - Parameters:
    ///   - cleanCacheTime: 캐시 정리 시간
    ///   - cacheType: 업데이트할 캐시 타입
    public func updateCleanCacheTime(
        cleanCacheTime: JwCacheExpiration,
        cacheType: CacheType
    ) {
        switch cacheType {
        case .memory:
            self.cleanMemoryCacheExpiredTime = cleanCacheTime
            startCleanMemoryCacheTimer()
        case .disk:
            self.cleanDiskCacheExpiredTime = cleanCacheTime
            startCleanDiskCacheTimer()
        }
    }
}

// MARK: - Clean Caches
extension JwImageCache {
    
    private func startCleanCacheTimer() {
        startCleanMemoryCacheTimer()
        startCleanDiskCacheTimer()
    }
    
    private func startCleanMemoryCacheTimer() {
        cleanCacheTask?.cancel()
        
        cleanCacheTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    if #available(iOS 16.0, *) {
                        try await Task.sleep(for: .seconds(self.cleanMemoryCacheExpiredTime.timeInterval))
                    } else {
                        try await Task.sleep(nanoseconds: UInt64(self.cleanMemoryCacheExpiredTime.timeInterval * 1_000_000_000))
                    }
                    
                    guard !Task.isCancelled else { break }
                    self.cleanExpiredMemoryCacheData()
                } catch {
                    break
                }
            }
        }
    }
    
    private func startCleanDiskCacheTimer() {
        // TODO: 마지막 디스크 청소 시간 기준으로 타이머 구현
    }
}

// MARK: - Memory Cache
extension JwImageCache {
    
    private func saveMemoryCache(key: String, data: JwImageData) {
        let dataSize = JwDataSize.bytes(Int64(data.data.count))
        
        if dataSize.byte <= memoryCache.config.totalCostLimit.byte {
            let cacheItem = ImageCacheItem(
                expiration: memoryCacheItemExpiredTime,
                standardExpiration: memoryCacheItemStandardExpiration,
                data: data,
                size: dataSize
            )
            
            do {
                try memoryCache.saveCache(key: NSString(string: key), value: cacheItem)
            } catch {
                print("❌ [JwImageCache] Memory cache save failed: \(error)")
            }
        } else {
            print("⚠️ [JwImageCache] Memory cache - data is bigger than size limit")
        }
    }
    
    private func cleanExpiredMemoryCacheData() {
        let removedCount = memoryCache.cleanExpiredData()
    }
}

// MARK: - Disk Cache
extension JwImageCache {
    
    private func saveDiskCache(key: String, data: JwImageData) {
        let dataSize = JwDataSize.bytes(Int64(data.data.count))
        
        if dataSize.byte <= diskCache.config.fileSizeLimit.byte {
            let cacheItem = ImageCacheItem(
                expiration: diskCacheItemExpiredTime,
                standardExpiration: diskCacheItemStandardExpiration,
                data: data,
                size: dataSize
            )
            
            do {
                try diskCache.saveCache(key: NSString(string: key), value: cacheItem)
            } catch {
                print("❌ [JwImageCache] Disk cache save failed: \(error)")
            }
        } else {
            print("⚠️ [JwImageCache] Disk cache - data is bigger than size limit")
        }
    }
    
    private func cleanExpiredDiskCacheData() {
        let removedCount = diskCache.cleanExpiredData()
    }
}
