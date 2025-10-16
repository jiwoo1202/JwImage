//
//  UIImageView+Jw.swift
//  JwImage
//
//  Created by heojiwoo on 2025/10/15.
//

import UIKit

// MARK: - Associated Key
private struct JwAssociatedKeys {
    nonisolated(unsafe) static var downloadUrl: UInt8 = 0
}

@MainActor
extension JwImageWrapper where Base: UIImageView {
    
    /// UIImageView가 현재 다운로드 중인 URL
    private var downloadUrl: String? {
        get { getAssociatedObject(base, &JwAssociatedKeys.downloadUrl) }
        set { setRetainedAssociatedObject(base, &JwAssociatedKeys.downloadUrl, newValue) }
    }
    
    /// URL을 이용해 이미지를 로드하고 다운샘플링 처리하여 표시합니다.
    /// - Parameters:
    ///   - url: 이미지 URL
    ///   - placeholder: 로딩 중 표시할 placeholder 이미지
    ///   - waitPlaceholderTime: placeholder 갱신 간격 (기본값 1초)
    ///   - options: 적용할 옵션 (`JwOption`)
    public func setImage(
        with url: URL,
        placeholder: UIImage? = nil,
        waitPlaceholderTime: TimeInterval = 1.0,
        options: Set<JwOption>? = nil
    ) {
        let options = options ?? [.downsamplingScale(1.0)]
        
        var mutableSelf = self
        mutableSelf.downloadUrl = url.absoluteString
        
        Task {
            var timer: Timer? = nil
            if placeholder != nil {
                timer = createPlaceholderTimer(placeholder, waitTime: waitPlaceholderTime)
                timer?.fire()
            }
            defer { timer?.invalidate() }
            
            guard let imageData = await fetchImage(with: url, options: options) else {
                updateImage(nil)
                return
            }
            
            if options.contains(.showOriginalImage) {
                updateImage(imageData.data.convertToImage())
                return
            }
            
            var downsamplingScale: CGFloat = 1.0
            for case let .downsamplingScale(scale) in options {
                downsamplingScale = scale
            }
            
            if let downsampled = imageData
                .data
                .downsampling(to: self.base.frame.size, scale: downsamplingScale) {
                updateImage(downsampled)
            } else {
                updateImage(imageData.data.convertToImage())
            }
        }
    }
    
    /// URL을 이용해 원본 이미지를 설정합니다.
    public func setOriginalImage(
        with url: URL,
        placeholder: UIImage? = nil,
        waitPlaceholderTime: TimeInterval = 1.0,
        options: Set<JwOption>? = nil
    ) {
        let options = options ?? [.showOriginalImage]
        setImage(with: url,
                 placeholder: placeholder,
                 waitPlaceholderTime: waitPlaceholderTime,
                 options: options)
    }
    
    /// memory cache → disk cache → network 순으로 이미지 로드
    private func fetchImage(with url: URL, options: Set<JwOption>) async -> JwImageData? {
        guard !options.contains(.forceRefresh) else {
            return try? await JwImageDownloader.shared.downloadImage(from: url)
        }
        return await JwImageCache.shared.getImageWithCache(url: url, options: options)
    }
    
    /// 메인 스레드에서 이미지 갱신
    private func updateImage(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.base.image = image
        }
    }
    
    /// 다운로드 취소
    public func cancelDownloadImage() {
        guard let downloadUrlString = downloadUrl,
              let url = URL(string: downloadUrlString) else { return }
        
        Task {
            await JwImageDownloader.shared.cancelDownloadImage(url: url)
        }
    }
}

// MARK: - Placeholder Timer
@MainActor
private extension JwImageWrapper where Base: UIImageView {

    func createPlaceholderTimer(_ placeholder: UIImage?, waitTime: TimeInterval) -> Timer? {
        guard let placeholder = placeholder else { return nil }

        let imageView = base

        let timer = Timer.scheduledTimer(withTimeInterval: waitTime, repeats: true) { @Sendable _ in
            Task { @MainActor in
                imageView.image = placeholder
            }
        }
        return timer
    }
}

// MARK: - Associated Object Helpers
private extension JwImageWrapper {
    func getAssociatedObject<T>(_ object: Any, _ key: UnsafeRawPointer) -> T? {
        objc_getAssociatedObject(object, key) as? T
    }

    func setRetainedAssociatedObject<T>(_ object: Any, _ key: UnsafeRawPointer, _ value: T) {
        objc_setAssociatedObject(object, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
