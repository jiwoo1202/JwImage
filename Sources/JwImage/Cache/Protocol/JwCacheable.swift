//
//  JwCacheable.swift
//  JwImage
//
//  Created by heojiwoo on 10/13/25.
//

import Foundation

// MARK: - 기본 캐시 프로토콜
public protocol JwCacheable {
    associatedtype Key: Hashable
    associatedtype Value: JwCacheItemable

    /// 캐시에 데이터 저장
    func saveCache(key: Key, value: Value) throws
    /// 캐시에서 데이터 조회
    func getCache(key: Key) -> Value?
    /// 특정 캐시 삭제
    func removeCache(key: Key)
    /// 전체 캐시 삭제
    func removeAll()
}

// MARK: - 캐시 아이템 프로토콜
public protocol JwCacheItemable: Codable {
    associatedtype T

    /// 실제 캐시 데이터
    var data: T { get set }
    var size: JwDataSize { get }
    /// 캐시 만료 정책
    var expiration: JwCacheExpiration { get }
    /// 만료 기준 (생성 시점 / 마지막 접근 시점)
    var standardExpiration: JwCacheExpirationStandard { get }
    /// 캐시 생성 시각
    var firstCachedTimeInterval: TimeInterval { get }
    /// 마지막 접근 시각
    var lastHitTimeInterval: TimeInterval { get set }
    /// 캐시 조회(hit) 횟수
    var hitCount: Int { get set }
    /// 현재 시점 기준 만료 여부
    var isExpired: Bool { get }
}
