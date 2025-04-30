//
//  RTP+Packet.swift
//  MUCE
//
//  Created by Kota on 4/9/R7.
//
extension RTP {
	public struct Packet: Sendable {
		@usableFromInline let status: Status
		@usableFromInline let type: `Type`
		@usableFromInline let sequence: UInt16
		@usableFromInline let timestamp: UInt32
		@usableFromInline let synchronization: UInt32
		@usableFromInline let contributions: Array<UInt32>
		@usableFromInline let extensions: Optional<Extension>
		@usableFromInline let payload: Array<UInt8>
	}
}
extension RTP.Packet {
	public enum Error: Swift.Error {
		case status
		case version
		case type
		case sequence
		case timestamp
		case synchronization
		case contributors
		case`extension`
		case padding
	}
}
extension RTP.Packet {
	public init(
		source: UInt32,
		contributions: some Sequence<UInt32>,
		sequence: UInt16,
		timestamp: UInt32,
		type: `Type`,
		payload: Array<UInt8>) {
			status = [.init(version: 2),.Padding]
			self.type = type
			self.sequence = sequence
			self.timestamp = timestamp
			self.synchronization = source
			self.contributions = .init(contributions.prefix(15))
			self.extensions = .none
			self.payload = payload
	}
	public init(
		source: UInt32,
		contributions: some Sequence<UInt32>,
		sequence: UInt16,
		timestamp: UInt32,
		type: `Type`,
		payload: Array<UInt8>,
		extension: Extension) {
			status = [.init(version: 2),.Padding,.Extension]
			self.type = type
			self.sequence = sequence
			self.timestamp = timestamp
			self.synchronization = source
			self.contributions = .init(contributions.prefix(15))
			self.extensions = .some(`extension`)
			self.payload = payload
	}
}
extension RTP.Packet {
	@_disfavoredOverload
	@inlinable
	public init<T>(from rawValue: T) throws (Error) where T: Collection<UInt8>, T.SubSequence == T.SubSequence.SubSequence {
		try self.init(from: rawValue.prefix(.max))
	}
	public init<T>(from rawValue: T) throws (Error) where T: Collection<UInt8>, T.SubSequence == T {
		var cursor = rawValue
		status = switch cursor.popFirst() {
		case.some(let value):
			.init(rawValue: value)
		case.none:
			throw.status
		}
		guard status.version == 2 else { throw.version }
		type = switch cursor.popFirst() {
		case.some(let value):
			.init(rawValue: value)
		case.none:
			throw.type
		}
		sequence = switch cursor.popElement().map(UInt16.init(bigEndian:)) {
		case.some(let value):
			value
		case.none:
			throw.sequence
		}
		timestamp = switch cursor.popElement().map(UInt32.init(bigEndian:)) {
		case.some(let field):
			field
		case.none:
			throw.timestamp
		}
		synchronization = switch cursor.popElement().map(UInt32.init(bigEndian:)) {
		case.some(let field):
			field
		case.none:
			throw.synchronization
		}
		contributions = repeatElement((), count: .init(truncatingIfNeeded: status.channel)).compactMap {
			cursor.popElement()
		}
		guard contributions.count == status.channel else { throw.contributors }
		extensions = if status.contains(.Extension) {
			switch Extension(parse: &cursor) {
			case.some(let value):
				.some(value)
			case.none:
				throw.extension
			}
		} else {
			.none
		}
		payload = if status.contains(.Padding) {
			switch cursor.suffix(1).first {
			case.some(let value):
				.init(cursor.dropLast(.init(value)))
			case.none:
				throw.padding
			}
		} else {
			.init(cursor)
		}
	}
}
extension RTP.Packet {
	func padding(count: Int, value: UInt8 = .zero) -> Array<UInt8> {
		repeatElement(value, count: count) + [.init(truncatingIfNeeded: count + 1)]
	}
	public func encode(alignment: Int = 4) -> Array<UInt8> {
		if let extensions, ( extensions.payload.count + payload.count ) % alignment == .zero {
			([
				[
					Status(version: 2).union([.init(channel: contributions.count), .Extension]).rawValue,
					type.rawValue
				],
				withUnsafeBytes(of: sequence.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: timestamp.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: synchronization.bigEndian, Array<UInt8>.init),
				contributions.flatMap {
					withUnsafeBytes(of: $0, Array<UInt8>.init)
				},
				extensions.encode(),
				payload,
			] as Array<Array<UInt8>>).flatMap(\.self)
		} else if let extensions {
			([
				[
					Status(version: 2).union([.init(channel: contributions.count), .Extension, .Padding]).rawValue,
					type.rawValue
				],
				withUnsafeBytes(of: sequence.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: timestamp.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: synchronization.bigEndian, Array<UInt8>.init),
				contributions.flatMap {
					withUnsafeBytes(of: $0, Array<UInt8>.init)
				},
				extensions.encode(),
				payload,
				padding(count: alignment - ( extensions.payload.count + payload.count ) % alignment - 1)
			] as Array<Array<UInt8>>).flatMap(\.self)
		} else if payload.count % alignment == .zero {
			([
				[
					Status(version: 2).union([.init(channel: contributions.count)]).rawValue,
					type.rawValue
				],
				withUnsafeBytes(of: sequence.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: timestamp.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: synchronization.bigEndian, Array<UInt8>.init),
				contributions.flatMap {
					withUnsafeBytes(of: $0, Array<UInt8>.init)
				},
				payload
			] as Array<Array<UInt8>>).flatMap(\.self)
		} else {
			([
				[
					Status(version: 2).union([.init(channel: contributions.count), .Padding]).rawValue,
					type.rawValue
				],
				withUnsafeBytes(of: sequence.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: timestamp.bigEndian, Array<UInt8>.init),
				withUnsafeBytes(of: synchronization.bigEndian, Array<UInt8>.init),
				contributions.flatMap {
					withUnsafeBytes(of: $0, Array<UInt8>.init)
				},
				payload,
				padding(count: alignment - payload.count % alignment - 1)
			] as Array<Array<UInt8>>).flatMap(\.self)
		}
	}
}
extension RTP.Packet: Hashable {
	public static func==(lhs: Self, rhs: Self) -> Bool {[(
		lhs.status,
		lhs.type,
		lhs.sequence,
		lhs.timestamp,
		lhs.synchronization,
		lhs.contributions
	) == (
		rhs.status,
		rhs.type,
		rhs.sequence,
		rhs.timestamp,
		rhs.synchronization,
		rhs.contributions
	),
		lhs.extensions == rhs.extensions,
		lhs.payload == rhs.payload
	].allSatisfy(\.self)}
	public func hash(into hasher: inout Hasher) {
		status.hash(into: &hasher)
		type.hash(into: &hasher)
		sequence.hash(into: &hasher)
		timestamp.hash(into: &hasher)
		synchronization.hash(into: &hasher)
		contributions.hash(into: &hasher)
		extensions?.hash(into: &hasher)
		payload.hash(into: &hasher)
	}
}
extension RTP.Packet {
	@dynamicMemberLookup
	public struct Status: Sendable & RawRepresentable {
		public typealias RawValue = UInt8
		public let rawValue: UInt8
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
	}
}
extension RTP.Packet.Status {
	subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension RTP.Packet.Status: OptionSet {
	public static let Padding   = Self(rawValue: 0b0010_0000)
	public static let Extension = Self(rawValue: 0b0001_0000)
}
extension RTP.Packet.Status: Hashable {}
extension RTP.Packet.Status {
	public init(version: some BinaryInteger) {
		rawValue = .init(truncatingIfNeeded: (version << 6) & 0b1100_0000)
	}
	public var version: Int {
		.init(truncatingIfNeeded: (rawValue & 0b1100_0000) >> 6)
	}
}
extension RTP.Packet.Status {
	public init(channel: some BinaryInteger) {
		rawValue = .init(truncatingIfNeeded: (channel << 0) & 0b0000_1111)
	}
	public var channel: Int {
		.init(truncatingIfNeeded: (rawValue & 0b0000_1111) >> 0)
	}
}
extension RTP.Packet {
	@dynamicMemberLookup
	public struct `Type`: Sendable, Hashable, RawRepresentable {
		public typealias RawValue = UInt8
		public let rawValue: UInt8
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
	}
}
extension RTP.Packet.`Type` {
	subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension RTP.Packet.`Type` {
	public static let PCMU    = Self(rawValue: 0)
	public static let GSM     = Self(rawValue: 3)
	public static let G723    = Self(rawValue: 4)
	public static let DVI4_8  = Self(rawValue: 5)
	public static let DVI4_16 = Self(rawValue: 6)
	public static let LPC     = Self(rawValue: 7)
	public static let PCMA    = Self(rawValue: 8)
	public static let G722    = Self(rawValue: 9)
	public static let L16_2ch = Self(rawValue: 10)
	public static let L16_1ch = Self(rawValue: 11)
	public static let QCELP   = Self(rawValue: 12)
	public static let CN      = Self(rawValue: 13)
	public static let MPA     = Self(rawValue: 14)
	public static let G728    = Self(rawValue: 15)
	public static let DVI4_11 = Self(rawValue: 16)
	public static let DVI4_22 = Self(rawValue: 17)
	public static let G729    = Self(rawValue: 18)
	public static let CelB    = Self(rawValue: 25)
	public static let JPEG    = Self(rawValue: 26)
	public static let nv      = Self(rawValue: 28)
	public static let H261    = Self(rawValue: 31)
	public static let MPV     = Self(rawValue: 32)
	public static let MP2T    = Self(rawValue: 33)
	public static let H263    = Self(rawValue: 34)
}
extension RTP.Packet {
	public struct Extension: Sendable, Hashable {
		@usableFromInline let profile: UInt16
		@usableFromInline let payload: Array<UInt8>
	}
}
extension RTP.Packet.Extension {
	init?<T>(parse: inout T) where T: Collection, T.SubSequence == T, T.Element == UInt8 {
		guard let head = parse.popElement() as Optional<UInt16> else {
			return nil
		}
		profile = head
		guard let size = parse.popElement().map(UInt16.init(bigEndian:)).flatMap(Int.init(exactly:)), let body = parse.popPayload(count: size) else {
			return nil
		}
		payload = .init(body)
	}
}
extension RTP.Packet.Extension {
	func encode() -> Array<UInt8> {
		withUnsafeBytes(of: profile, Array<UInt8>.init) +
		withUnsafeBytes(of: UInt16(truncatingIfNeeded: payload.count).bigEndian, Array<UInt8>.init) +
		payload
	}
}
