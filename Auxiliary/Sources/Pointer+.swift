//
//  Pointer+.swift
//  MUCE
//
//  Created by Kota on 10/10/26.
//
extension UnsafePointer {
    @inlinable@inline(__always)@_transparent
    public static var null: Self {
        unsafeBitCast(.none as Optional<Self>, to: Self.self)
    }
}
extension UnsafeMutablePointer {
    @inlinable@inline(__always)@_transparent
    public static var null: Self {
        unsafeBitCast(.none as Optional<Self>, to: Self.self)
    }
}
extension UnsafeRawPointer {
    nonisolated(unsafe)
    public static let null: Self = unsafeBitCast(.none as Optional<Self>, to: Self.self)
}
extension UnsafeMutableRawPointer {
    nonisolated(unsafe)
    public static let null: Self = unsafeBitCast(.none as Optional<Self>, to: Self.self)
}
extension UnsafeBufferPointer {
    @inlinable@inline(__always)@_transparent
    public static var none: Self {
        .init(start: .none, count: 0)
    }
}
extension UnsafeMutableBufferPointer {
    @inlinable@inline(__always)@_transparent
    public static var none: Self {
        .init(start: .none, count: 0)
    }
}
extension UnsafeRawBufferPointer {
    nonisolated(unsafe)
    public static let none: Self = .init(start: .none, count: 0)
}
extension UnsafeMutableRawBufferPointer {
    nonisolated(unsafe)
    public static let none: Self = .init(start: .none, count: 0)
}
