//
//  Integer+.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
@inlinable@inline(__always)
func gcd<T: BinaryInteger>(_ x: T, _ y: T) -> T {
	y == 0 ? x : gcd(y, x % y)
}
@inlinable@inline(__always)
func mod<T: BinaryInteger>(_ x: T, _ y: T) -> T {
	y == 0 ? 0 : x % y
}
@inlinable@inline(__always)
func div<T: BinaryInteger>(_ x: T, _ y: T) -> T {
	y == 0 ? 0 : x / y
}
extension BinaryInteger {
	@inlinable@inline(__always)
	var squareRoot: Self {
		1 < self ? sequence(state: self / 2) { s in
			let t = ( s + self / s ) / 2
			defer {
				s = t
			}
			return (s, t)
		}.first(where: <=).unsafelyUnwrapped.0 : self
	}
}
