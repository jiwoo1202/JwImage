//
//  JwDataSize.swift
//  JwImage
//
//  Created by heojiwoo on 10/13/25.
//

import Foundation

public enum JwDataSize: Codable {
    case bytes(Int64)
    case kb(Int64)
    case mb(Int64)
    case gb(Int64)
    case infinity
    
    public var byte: Int64 {
        switch self {
        case .bytes(let value):
            return value
        case .kb(let value):
            return value * 1024
        case .mb(let value):
            return value * 1024 * 1024
        case .gb(let value):
            return value * 1024 * 1024 * 1024
        case .infinity:
            return Int64.max
        }
    }
    
    public var kiloByte: Double {
        if case .infinity = self { return Double.infinity }
        return Double(byte) / 1024.0
    }
    
    public var megaByte: Double {
        if case .infinity = self { return Double.infinity }
        return Double(byte) / (1024.0 * 1024.0)
    }
    
    public var gigaByte: Double {
        if case .infinity = self { return Double.infinity }
        return Double(byte) / (1024.0 * 1024.0 * 1024.0)
    }
}
