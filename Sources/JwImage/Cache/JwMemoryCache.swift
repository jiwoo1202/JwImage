//
//  JwMemoryCache.swift
//  JwImage
//
//  Created by heojiwoo on 2025/10/13.
//

import UIKit

/// NSCache 기반 메모리 캐시 시스템
/// - Thread-safe
/// - 자동 만료 및 정리 지원 (외부 타이머 or Task로 관리)
/// - Config 기반 확장 가능
open class JwMemoryCache<Key: AnyObject & Hashable, Value: JwCacheItemable>: JwCacheable {

    /// 캐시 동작 설정값
    public struct Config {
        /// 총 메모리 사용량 제한 (bytes 단위)
        public var totalCostLimit: JwDataSize
        /// 캐시에 저장 가능한 객체 수 제한
        public var countLimit: Int
        /// 백그라운드 진입 시 캐시 유지 여부
        public var keepWhenEnteringBackground: Bool

        public init(
            totalCostLimit: JwDataSize = .mb(8192),
            countLimit: Int = 1000,
            expiration: JwCacheExpiration = .minutes(5),
            keepWhenEnteringBackground: Bool = false
        ) {
            self.totalCostLimit = totalCostLimit
            self.countLimit = countLimit
            self.keepWhenEnteringBackground = keepWhenEnteringBackground
        }
    }
    
    /// NSCache에 구조체(Value)를 담기 위한 클래스 래퍼
    private final class CacheBox {
        var item: Value
        init(_ item: Value) { self.item = item }
    }
    
    // MARK: - Properties
    private let cache = NSCache<Key, CacheBox>()
    private var keys: Set<Key> = []
    private let lock = NSLock()
    
    public var config: Config {
        didSet {
            cache.totalCostLimit = Int(config.totalCostLimit.byte)
            cache.countLimit = config.countLimit
        }
    }

    // MARK: - Init
    public init(config: Config = .init()) {
        self.config = config
        cache.totalCostLimit = Int(config.totalCostLimit.byte)
        cache.countLimit = config.countLimit
    }

    // MARK: - Cache Operations
    /// 캐시에 데이터 저장 (자동 덮어쓰기)
    open func saveCache(key: Key, value: Value) throws {
        lock.lock()
        defer { lock.unlock() }

        let box = CacheBox(value)
        cache.setObject(box, forKey: key, cost: Int(value.size.byte))
        keys.insert(key)
    }

    /// 캐시에서 데이터 조회 (만료 시 자동 제거)
    open func getCache(key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let box = cache.object(forKey: key) else { return nil }
        var item = box.item

        if item.isExpired {
            cache.removeObject(forKey: key)
            keys.remove(key)
            return nil
        }

        // lastHitTime 갱신
        item.lastHitTimeInterval = Date().timeIntervalSince1970
        box.item = item
        return item
    }

    /// 특정 캐시 삭제
    open func removeCache(key: Key) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeObject(forKey: key)
        keys.remove(key)
    }

    /// 전체 캐시 삭제
    open func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAllObjects()
        keys.removeAll()
    }

    /// 만료된 항목 정리
    @discardableResult
    open func cleanExpiredData() -> Int {
        lock.lock()
        defer { lock.unlock() }

        var removed = 0
        for key in Array(keys) {
            if let box = cache.object(forKey: key), box.item.isExpired {
                cache.removeObject(forKey: key)
                keys.remove(key)
                removed += 1
            }
        }
        return removed
    }

    // MARK: - Background Handling
    open func handleAppDidEnterBackground() {
        guard !config.keepWhenEnteringBackground else { return }
        removeAll()
    }
}
