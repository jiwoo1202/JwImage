//
//  JwImage.swift
//  JwImage
//
//  Created by heojiwoo on 10/15/25.
//

import UIKit

public struct JwImageWrapper<Base> {
    
    public let base: Base
    
    public init(base: Base) {
        self.base = base
    }
}

public protocol JwImageWrapperCompatible: AnyObject {}

extension JwImageWrapperCompatible {
    /// Wrapping Value
    public var jw: JwImageWrapper<Self> {
        return JwImageWrapper(base: self)
    }
}

extension UIImageView: JwImageWrapperCompatible {}
