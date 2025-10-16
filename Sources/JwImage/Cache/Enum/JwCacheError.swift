//
//  JwCacheError.swift
//  JwImage
//
//  Created by heojiwoo on 10/13/25.
//

import Foundation

/// Cache에서 발생하는 에러
public enum JwCacheError: LocalizedError {
    case saveError
    case fetchError
    case deleteError
}

extension JwCacheError {
    public var errorDescription: String? {
        switch self {
        case .saveError: return "캐시 save 에러"
        case .fetchError: return "캐시 fetch 에러"
        case .deleteError: return "캐시 delete 에러"
        }
    }
}
