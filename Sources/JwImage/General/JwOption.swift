//
//  JwOption.swift
//  JwImage
//
//  Created by heojiwoo on 10/15/25.
//

import Foundation

public enum JwOption: Hashable, Sendable {
    
    /// 이미지를 메모리 캐시에만 저장합니다.
    /// 디스크 캐시는 사용하지 않습니다.
    /// - 사용 예: 휘발성 이미지를 빠르게 로드할 때.
    case cacheMemoryOnly
    /// 이미지를 **캐시에서만** 불러옵니다.
    /// 캐시에 없는 경우 네트워크 요청을 시도하지 않습니다.
    /// - 사용 예: 오프라인 모드나 캐시 검증 용도.
    case onlyFromCache
    /// 캐시를 무시하고 항상 네트워크에서 이미지를 새로 다운로드합니다.
    /// 기존 캐시는 갱신됩니다.
    /// - 사용 예: 서버 이미지가 자주 변경될 때 강제 갱신 용도.
    case forceRefresh
    /// 다운샘플링 없이 원본 해상도의 이미지를 표시합니다.
    /// 기본적으로는 `UIImageView` 크기에 맞춰 다운샘플링이 이루어집니다.
    /// - 주의: 큰 이미지를 표시할 경우 메모리 사용량이 급격히 늘어날 수 있습니다.
    case showOriginalImage
    /// ETag(HTTP 캐시 검증 헤더)를 사용하지 않습니다.
    /// 항상 서버에서 완전한 응답을 받습니다.
    /// - 사용 예: 서버 캐시 정책을 무시하고 싶을 때.
    case disableETag
    /// 다운샘플링 비율을 수동으로 지정합니다.
    /// 예: `1.0` → 뷰 크기와 동일한 크기로, `2.0` → 두 배 크기로 디코딩
    /// - 파라미터: `scale` 다운샘플링 비율 (기본값 1.0)
    case downsamplingScale(CGFloat)
}
