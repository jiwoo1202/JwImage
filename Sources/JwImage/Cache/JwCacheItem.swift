//
//  JwCacheItem.swift
//  JwImage
//
//  Created by heojiwoo on 10/13/25.
//
import Foundation

/// 캐시에 저장되는 개별 아이템 구조체
/// - 만료 시간, 히트 카운트, 데이터 크기 등 캐시 메타데이터 포함
public struct JwCacheItem<T: Codable>: JwCacheItemable {

    // MARK: - Metadata
    /// 데이터 크기
    public var size: JwDataSize
    /// 캐시 조회 횟수
    public var hitCount: Int
    /// 만료 시간
    public var expiration: JwCacheExpiration
    /// 만료 기준
    public var standardExpiration: JwCacheExpirationStandard
    /// 처음 캐싱된 시점
    public var firstCachedTimeInterval: TimeInterval
    /// 처음 캐싱된 시간
    public var firstCachedDate: Date {
        Date(timeIntervalSince1970: firstCachedTimeInterval)
    }
    /// 마지막으로 Hit된 시점
    public var lastHitTimeInterval: TimeInterval
    /// 마지막으로 Hit된 시간
    public var lastHitDate: Date {
        Date(timeIntervalSince1970: lastHitTimeInterval)
    }
    /// 만료 기준에 따라 계산된 만료 시각
    public var expiredDate: Date {
        switch standardExpiration {
        case .create:
            return firstCachedDate.addingTimeInterval(expiration.timeInterval)
        case .lastHit:
            return lastHitDate.addingTimeInterval(expiration.timeInterval)
        }
    }
    /// 만료 여부
    public var isExpired: Bool {
        expiredDate < Date()
    }

    // MARK: - Data
    public var data: T

    // MARK: - Initializer
    /// - Parameters:
    ///   - expiration: 캐시 만료 시간 설정.
    ///                 기본값은 `.minutes(5)`로, 생성 시점 또는 마지막 접근 시점 기준 5분간 유지됩니다.
    ///   - standardExpiration: 만료 기준 시점.
    ///                 `.create`는 생성 시점 기준, `.lastHit`는 마지막 접근 기준입니다.
    ///                 기본값은 `.lastHit`.
    ///   - data: 실제 캐시할 데이터 (`Codable`을 준수해야 함).
    ///   - size: 데이터의 크기를 나타내는 값 (`JwDataSize` 단위로 표시).
    ///
    /// - Important: `firstCachedTimeInterval`은 생성 시 자동으로 현재 시각으로 설정됩니다.
    ///              `hitCount`는 0으로 초기화되며, 이후 캐시에 접근할 때마다 증가시킬 수 있습니다.
    public init(priority: Int = 0,
                expiration: JwCacheExpiration = .minutes(5),
                standardExpiration: JwCacheExpirationStandard = .create,
                data: T,
                size: JwDataSize) {
        self.expiration = expiration
        self.standardExpiration = standardExpiration
        self.data = data
        self.size = size
        self.firstCachedTimeInterval = Date().timeIntervalSince1970
        self.lastHitTimeInterval = firstCachedTimeInterval
        self.hitCount = 0
    }
}
