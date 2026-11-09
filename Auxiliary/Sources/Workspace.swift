//
//  Workspace.swift
//  MUCE
//
//  Created by Kota on 11/9/26.
//
public enum Workspace {}
extension Workspace {
    public struct Typed<T: BitwiseCopyable>: ~Copyable {
        @usableFromInline
        var memory: UnsafeMutableBufferPointer<T>.SubSequence
        @inlinable@_transparent@inline(__always)
        init(base: UnsafeMutableBufferPointer<T>) {
            memory = base[...]
        }
    }
}
extension Workspace.Typed {
    @inlinable@_transparent@inline(__always)
    public mutating func consume(prefix count: Int) -> UnsafeMutableBufferPointer<T> {
        precondition(count <= memory.count)
        defer {
            memory.removeFirst(count)
        }
        return.init(rebasing: memory.prefix(count))
    }
}
extension Workspace {
    @inlinable@_transparent@inline(__always)
    public static func alloc<T: BitwiseCopyable, E, R>(of type: T.Type, capacity: Int, body: (inout Typed<T>) throws (E) -> R) rethrows -> R {
        try withUnsafeTemporaryAllocation(of: type, capacity: capacity) {
            var workspace = Typed(base: $0)
            return try body(&workspace)
        }
    }
}
extension Workspace {
    public struct Raw: ~Copyable {
        @usableFromInline
        var memory: UnsafeMutableRawBufferPointer.SubSequence
        @inlinable@_transparent@inline(__always)
        init(base: UnsafeMutableRawBufferPointer) {
            memory = base[...]
        }
    }
}
extension Workspace.Raw {
    @inlinable@_transparent@inline(__always)
    public mutating func consume(prefix capacity: Int, alignment: Optional<Int> = .none) -> UnsafeMutableRawBufferPointer {
        precondition(capacity <= memory.count)
        if let alignment, let base = memory.base.baseAddress {
            let current = Int(bitPattern: base.advanced(by: memory.startIndex))
            switch current % alignment {
            case 0:
                break
            case let remainder:
                memory.removeFirst(alignment - remainder)
            }
        }
        defer {
            memory.removeFirst(capacity)
        }
        return.init(rebasing: memory.prefix(capacity))
    }
    @inlinable@_transparent@inline(__always)
    public mutating func consume<T: BitwiseCopyable>(of type: T.Type, capacity: Int) -> UnsafeMutableBufferPointer<T> {
        consume(prefix: capacity * MemoryLayout<T>.stride, alignment: .some(MemoryLayout<T>.alignment)).bindMemory(to: T.self)
    }
}
extension Workspace {
    @inlinable@_transparent@inline(__always)
    public static func alloc<E, R>(byteCount: Int, alignment: Int, body: (inout Raw) throws (E) -> R) rethrows -> R {
        try withUnsafeTemporaryAllocation(byteCount: byteCount, alignment: alignment) {
            var workspace = Raw(base: $0)
            return try body(&workspace)
        }
    }
}
