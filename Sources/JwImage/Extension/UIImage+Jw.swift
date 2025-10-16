//
//  UIImage+Jw.swift
//  JwImage
//
//  Created by heojiwoo on 10/15/25.
//
import UIKit

public enum JwImageFormat: Codable {
    case png
    case jpeg(compressionQuality: CGFloat = 1.0)
}

extension UIImage {
    /// UIImage를 Data로 변환
    /// - Parameter format: 이미지 format
    /// - Returns: UIImage를 변환한 data
    public func convertToData(format: JwImageFormat) -> Data? {
        switch format {
        case .png:
            return self.pngData()
        case .jpeg(let compressionQuality):
            return self.jpegData(compressionQuality: compressionQuality)
        }
    }
}
