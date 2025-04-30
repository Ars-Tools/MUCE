//
//  RTPC+Packet.swift
//  MUCE
//
//  Created by Kota on 4/9/R7.
//
extension RTPC {
	public struct Packet: Sendable {
		
	}
}
extension RTPC.Packet {
	@dynamicMemberLookup
	public struct Status: Sendable {
		public typealias RawValue = UInt8
		public let rawValue: RawValue
		public init(rawValue: RawValue) {
			self.rawValue = rawValue
		}
	}
}
extension RTPC.Packet {
	public init(from raw: some Collection<UInt8>) {
		fatalError()
	}
	public func encode() -> Array<UInt8> {
		fatalError()
	}
}
extension RTPC.Packet.Status {
	subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension RTPC.Packet.Status {
	public init(version: some BinaryInteger) {
		rawValue = .init(truncatingIfNeeded: (version << 6) & 0b1100_0000)
	}
	public var version: Int {
		.init(truncatingIfNeeded: (rawValue & 0b1100_0000) >> 6)
	}
}
extension RTPC.Packet.Status {
	public init(channel: some BinaryInteger) {
		rawValue = .init(truncatingIfNeeded: (channel & 0b0001_1111))
	}
	public var channel: Int {
		.init(truncatingIfNeeded: rawValue & 0b0001_1111)
	}
}
extension RTPC.Packet.Status: OptionSet {
	public static let Padding = Self(rawValue: 0b0010_0000)
}
extension RTPC.Packet {
	public enum `Type`: UInt8 {
		case SR   = 200 // Sender Report
		case RR   = 201 // Receiver Report
		case SDES = 202 // Source Description
		case BYE  = 203 // Goodbye
		case APP  = 204 // Application Defined
		case FIR  = 192 // Full INTRA-Frame request
		case NACK = 193 // Negative acknowledgement
	}
}
extension RTPC.Packet.`Type` {
	
}
