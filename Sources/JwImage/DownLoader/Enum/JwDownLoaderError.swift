//
//  JwDownloaderError.swift
//  JwImage
//
//  Created by heojiwoo on 2025/10/17.
//

import Foundation

public enum JwDownloaderError: LocalizedError {
    case apiError
    case downloadImageError
    case urlError
    case notChangedETag
}

extension JwDownloaderError {
    public var errorDescription: String? {
        switch self {
        case .apiError:
            return "API 호출 에러"
        case .downloadImageError:
            return "이미지 다운로드 에러"
        case .urlError:
            return "잘못된 URL"
        case .notChangedETag:
            return "변경되지 않은 URL ETag 데이터"
        }
    }
}
