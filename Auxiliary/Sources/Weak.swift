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
extension Weak: Sendable where Ref: Sendable {}
extension Weak {
    @inlinable
    public subscript<R>(dynamicMember keyPath: KeyPath<Ref, R>) -> Optional<R> {
        _read {
            yield ref?[keyPath: keyPath]
        }
    }
//    @inlinable
//    public subscript<R>(dynamicMember keyPath: ReferenceWritableKeyPath<Ref, R>) -> Optional<R> {
//        _read {
//            yield ref?[keyPath: keyPath]
//        }
//        _modify {
//            yield &ref?[keyPath: keyPath]
//        }
//    }
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
