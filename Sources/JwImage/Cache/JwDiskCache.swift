//
//  JwDiskCache.swift
//  JwImage
//
//  Created by heojiwoo on 2025/10/16.
//

import Foundation

/// 디스크 기반 캐시
/// - Codable 기반 직렬화/역직렬화 지원
/// - 생성 시점 기준 만료 판단
/// - on-demand 기반의 수동 정리 구조
open class JwDiskCache<Key: Hashable, Value: JwCacheItemable & Codable>: JwCacheable {
    
    // MARK: - Config
    public struct Config {
        /// 캐시 폴더 이름
        public var folderName: String
        /// 디스크 캐시 총 용량 (기본 무제한)
        public var capacity: JwDataSize
        /// 단일 파일 최대 크기 (기본 무제한)
        public var fileSizeLimit: JwDataSize
        /// 만료 시간 (옵션)
        public var expiration: JwCacheExpiration?

        public init(
            folderName: String = "JwCache",
            capacity: JwDataSize = .infinity,
            fileSizeLimit: JwDataSize = .infinity,
            expiration: JwCacheExpiration? = nil
        ) {
            self.folderName = folderName
            self.capacity = capacity
            self.fileSizeLimit = fileSizeLimit
            self.expiration = expiration
        }
    }
    
    public var config: Config
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let directoryURL: URL

    // MARK: - Init
    public init(config: Config = .init()) {
        self.config = config
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directoryURL = baseURL.appendingPathComponent(config.folderName, isDirectory: true)
        createDirectory()
    }

    // MARK: - Save
    /// 디스크에 캐시 저장
    open func saveCache(key: Key, value: Value) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try JSONEncoder().encode(value)
        let fileSize = Int64(data.count)

        // 단일 파일 크기 제한
        guard fileSize <= config.fileSizeLimit.byte else {
            throw JwCacheError.saveError
        }

        // 전체 캐시 용량 제한 검사
        if currentDiskUsage + fileSize > config.capacity.byte {
            throw JwCacheError.saveError
        }

        let fileURL = cacheFileURL(forKey: key)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Get
    /// 디스크에서 캐시 데이터 조회 (만료 시 삭제)
    open func getCache(key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        let fileURL = cacheFileURL(forKey: key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        // 파일 생성일로 만료 확인
        if let expiration = config.expiration,
           let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let creationDate = attrs[.creationDate] as? Date,
           Date().timeIntervalSince(creationDate) > expiration.timeInterval {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL),
              var item = try? JSONDecoder().decode(Value.self, from: data) else {
            return nil
        }

        // 마지막 접근 시각 업데이트
        item.lastHitTimeInterval = Date().timeIntervalSince1970
        return item
    }

    // MARK: - Remove
    /// 특정 캐시 삭제
    open func removeCache(key: Key) {
        lock.lock()
        defer { lock.unlock() }

        let fileURL = cacheFileURL(forKey: key)
        try? fileManager.removeItem(at: fileURL)
    }

    /// 모든 캐시 삭제
    open func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        try? fileManager.removeItem(at: directoryURL)
        createDirectory()
    }

    // MARK: - Clean
    /// 만료된 캐시만 정리 (on-demand)
    @discardableResult
    open func cleanExpiredData() -> Int {
        lock.lock()
        defer { lock.unlock() }

        guard let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.creationDateKey]) else {
            return 0
        }

        var removedCount = 0
        for fileURL in files {
            if let expiration = config.expiration,
               let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attrs[.creationDate] as? Date,
               Date().timeIntervalSince(creationDate) > expiration.timeInterval {
                try? fileManager.removeItem(at: fileURL)
                removedCount += 1
            }
        }
        return removedCount
    }

    // MARK: - Util
    /// 현재 디스크 사용량 (bytes)
    public var currentDiskUsage: Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var total: Int64 = 0
        for fileURL in files {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? NSNumber {
                total += size.int64Value
            }
        }
        return total
    }
}

extension JwDiskCache {
    
    internal func createDirectory() {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            print("[JwDiskCache] Failed to create directory: \(error.localizedDescription)")
        }
    }
    
    internal func getCacheFolderUrl(folderName: String) -> URL? {
        guard let baseCacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return baseCacheURL.appendingPathComponent(folderName, isDirectory: true)
    }
    
    /// 키로부터 캐시 파일 URL 생성
    internal func cacheFileURL(forKey key: Key) -> URL {
        return directoryURL.appendingPathComponent("\(key.hashValue)")
    }
}
