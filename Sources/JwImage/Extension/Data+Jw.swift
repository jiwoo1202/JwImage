//
//  Data+JI.swift
//  JwImage
//
//  Created by heojiwoo on 10/13/25.
//
import UIKit

extension Data {
    public func convertToImage() -> UIImage? {
        return UIImage(data: self)
    }
    /// downsampling 메서드
    /// - Parameters:
    ///   - targetSize: downsampling 사이즈
    ///   - scale: scale 수치
    /// - Returns: downsampling 결과
    public func downsampling(to targetSize: CGSize, scale: CGFloat = 1) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(self as CFData, imageSourceOptions) else { return nil }
        
        let maxDimensionInPixels = Swift.max(targetSize.width, targetSize.height) * scale
        
        let downsamplingOptions = [
            // 항상 썸네일 생성 (이미지에 썸네일이 없어도)
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // 즉시 디코딩 & 캐시
            kCGImageSourceShouldCacheImmediately: true,
            // EXIF 방향 정보 적용 (회전 처리)
            kCGImageSourceCreateThumbnailWithTransform: true,
            // 최대 픽셀 크기 제한
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsamplingOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}
