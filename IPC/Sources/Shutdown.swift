//
//  Shutdown.swift
//  MUCE
//
//  Created by Kota on 3/30/R7.
//
import func Darwin.shutdown
import let Darwin.SHUT_RD
import let Darwin.SHUT_WR
import let Darwin.SHUT_RDWR
@dynamicMemberLookup
public struct Shutdown: RawRepresentable {
	public typealias RawValue = UInt8
	public let rawValue: RawValue
	public init(rawValue: RawValue = 0b00) {
		self.rawValue = rawValue
	}
}
extension Shutdown {
	public subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension Shutdown {
	@inlinable
	func apply(handle: Int32) -> Int32 {
		switch rawValue & 0b11 {
		case 0b01:shutdown(handle, SHUT_RD)
		case 0b10:shutdown(handle, SHUT_WR)
		case 0b11:shutdown(handle, SHUT_RDWR)
		default:.zero
		}
	}
}
extension Shutdown: OptionSet, Sendable {
	public static let recv = Self(rawValue: 0b01)
	public static let send = Self(rawValue: 0b10)
}
