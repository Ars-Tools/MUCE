//
//  Weak.swift
//  MUCE
//
//  Created by Kota on 11/29/25.
//
@dynamicMemberLookup
public struct Weak<Ref: AnyObject> {
    @usableFromInline
    weak var ref: Optional<Ref>
}
extension Weak {
    public static func some(_ value: Ref) -> Self {
        .init(ref: .some(value))
    }
    public var none: Weak<Ref> {
        .init(ref: .none)
    }
}
extension Weak: Sendable where Ref: Sendable {}
extension Weak: RawRepresentable {
    public init?(rawValue: Optional<Ref>) {
        switch rawValue {
        case.some(let valeu):
            self.init(ref: valeu)
        case.none:
            return nil
        }
    }
    public var rawValue: Optional<Ref> {
        ref
    }
}
extension Weak {
    @inlinable
    public subscript<R>(dynamicMember keyPath: KeyPath<Ref, R>) -> Optional<R> {
        _read {
            yield ref?[keyPath: keyPath]
        }
    }
    @inlinable
    public subscript<R>(dynamicMember keyPath: ReferenceWritableKeyPath<Ref, R>) -> Optional<R> {
        _read {
            yield ref?[keyPath: keyPath]
        }
        set {
            if let newValue {
                ref?[keyPath: keyPath] = newValue
            }
        }
    }
    @inlinable
    public subscript<R>(dynamicMember keyPath: WritableKeyPath<Ref, R>) -> Optional<R> {
        _read {
            yield ref?[keyPath: keyPath]
        }
        set {
            if let newValue {
                ref?[keyPath: keyPath] = newValue
            }
        }
    }
}
