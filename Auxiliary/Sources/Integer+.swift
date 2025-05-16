//
//  Integer+.swift
//  MUCE
//
//  Created by Kota on 5/16/R7.
//
@_disfavoredOverload
@inlinable@inline(__always)
public func mod<T: BinaryInteger>(_ x: T, _ y: T) -> T {
	y == 0 ? 0 : x % y
}
@_disfavoredOverload
@inlinable@inline(__always)
public func div<T: BinaryInteger>(_ x: T, _ y: T) -> T {
	y == 0 ? 0 : x / y
}
@_disfavoredOverload
@inlinable@inline(__always)
public func abs<T: BinaryInteger>(_ x: T) -> T { // obtain magnitude without any typecast
	x < 0 ? ~x + 1 : x
}
@_disfavoredOverload
@inlinable@inline(__always)
public func gcd<T: BinaryInteger>(_ x: T, _ y: T) -> T {
	y == 0 ? x : gcd(y, x % y)
}
extension BinaryInteger {
	@inlinable@inline(__always)
	public var squareRoot: Self {
		1 < self ? sequence(state: self / 2) { s in
			let t = ( s + self / s ) / 2
			defer {
				s = t
			}
			return (s, t)
		}.first(where: <=).unsafelyUnwrapped.0 : self
	}
}
