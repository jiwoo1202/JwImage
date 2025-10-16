//
//  JwCacheExpiration.swift
//  JwImage
//
//  Created by heojiwoo on 2025/10/13.
//

import Foundation

/// 캐시 아이템의 만료 시간
/// - never : 만료되지 않음
/// - seconds : 특정 초(TimeInterval) 이후 만료
/// - minutes : 분 단위 만료
/// - hours : 시간 단위 만료
/// - days : 일 단위 만료
/// - date : 특정 날짜를 초과하면 만료
/// - expired : 이미 만료됨
public enum JwCacheExpiration: Codable, Equatable {
    case never
    case seconds(TimeInterval)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case date(Date)
    case expired

    /// 만료까지 남은 시간(초 단위)
    public var timeInterval: TimeInterval {
        switch self {
        case .never:
            return .infinity
        case .seconds(let seconds):
            return seconds
        case .minutes(let minutes):
            return TimeInterval(minutes * 60)
        case .hours(let hours):
            return TimeInterval(hours * 3600)
        case .days(let days):
            return TimeInterval(days * 86400)
        case .date(let date):
            return date.timeIntervalSinceNow
        case .expired:
            return -.infinity
        }
    }

    /// 현재 시점 기준으로 만료 여부 계산
    public var isExpired: Bool {
        switch self {
        case .never:
            return false
        case .expired:
            return true
        case .date(let date):
            return Date() > date
        default:
            return timeInterval <= 0
        }
    }

    /// 캐시 생성 기준으로 실제 만료 시각 계산
    /// - Parameter base: 기준 시각 (create 또는 lastHit 등)
    /// - Returns: 만료되는 시각(Date)
    public func estimatedExpirationDate(from base: Date) -> Date {
        switch self {
        case .never:
            return .distantFuture
        case .expired:
            return .distantPast
        case .date(let date):
            return date
        default:
            return base.addingTimeInterval(timeInterval)
        }
    }
}

/// 캐시 만료의 기준 시점
/// - create : 캐시가 처음 생성된 시각 기준
/// - lastHit : 마지막으로 접근된 시각 기준
public enum JwCacheExpirationStandard: String, Codable {
    case create
    case lastHit
}
