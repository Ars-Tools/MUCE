//
//  TimeTag.swift
//  MUCE
//
//  Created by Kota on 3/31/R7.
//
import typealias Foundation.Date
import typealias Foundation.TimeInterval
import typealias CoreMedia.CMTime
import protocol Synchronization.AtomicRepresentable
import func Darwin.modf
import func Auxiliary.gcd
@frozen public struct TimeTag: RawRepresentable & Sendable & BitwiseCopyable & Codable {
	public typealias RawValue = UInt64
	public let rawValue: RawValue
	public init(rawValue: RawValue) {
		self.rawValue = rawValue
	}
}
extension TimeTag: ExpressibleByIntegerLiteral {
	public static let immediately: Self = 0
	public static let distantFuture: Self = .init(rawValue: ~0)
	@inlinable
	public init(integerLiteral value: UInt64) {
		rawValue = value << 32
	}
}
extension TimeTag: ExpressibleByFloatLiteral {
	public init(floatLiteral value: TimeInterval) {
		let (integer, fraction) = modf(value)
		rawValue = .init(integer) << 32 &+ .init(fraction * .init(1 << 32))
	}
}
extension TimeTag {
	public var seconds: TimeInterval {
		let integer = rawValue >> 32
		let fraction = rawValue % ( 1 << 32 )
		return.init(integer) + .init(fraction) / .init(1 << 32)
	}
}
extension TimeTag: Hashable {
	
}
extension TimeTag: Comparable {
	@inlinable
	public static func<(lhs: TimeTag, rhs: TimeTag) -> Bool {
		lhs.rawValue<rhs.rawValue
	}
	@inlinable
	public static func>(lhs: TimeTag, rhs: TimeTag) -> Bool {
		lhs.rawValue>rhs.rawValue
	}
	@inlinable
	public static func<=(lhs: TimeTag, rhs: TimeTag) -> Bool {
		lhs.rawValue<=rhs.rawValue
	}
	@inlinable
	public static func>=(lhs: TimeTag, rhs: TimeTag) -> Bool {
		lhs.rawValue>=rhs.rawValue
	}
}
extension TimeTag: AtomicRepresentable {}
extension TimeTag: CustomStringConvertible {
	@inlinable
	public var description: String {
		switch self {
		case.immediately:
			"immediately"
		case.distantFuture:
			"distantFuture"
		default:
			Duration(self).description
		}
	}
}
// with Date, offset 2_208_988_800 in RFC 868
extension TimeTag {
	public init(date: Date) {
		assert(MemoryLayout<RawValue>.size == 8)
		let (integer, fraction) = modf(date.timeIntervalSince1970)
		rawValue = (RawValue(integer) &+ 2_208_988_800) << 32 &+ RawValue(fraction * .init(1 << 32))
	}
}
extension Date {
	public init(_ time: TimeTag) {
		assert(MemoryLayout<TimeTag.RawValue>.size == 8)
		let integer = (time.rawValue >> 32 ) &- 2_208_988_800
		let fraction = time.rawValue % ( 1 << 32 )
		self.init(timeIntervalSince1970: .init(integer) + .init(fraction) / .init(1 << 32))
	}
}
// with Duration, by logb(10^18 / (gcd(10^18, 2^32) = 262144) = 3814697265625) = 41.7
extension TimeTag {
	public init(duration: Duration) {
		let (seconds, attoseconds) = duration.components
		let fraction = RawValue(attoseconds) &* 2 / 465661287
		rawValue = .init(seconds) << 32 &+ fraction
	}
}
extension Duration {
	public init(_ time: TimeTag) {
		let integer = time.rawValue >> 32
		let fraction = time.rawValue % ( 1 << 32 )
		self.init(secondsComponent: .init(integer), attosecondsComponent: .init(fraction) &* 1862645149 / 8 )
	}
}
// with CMTime
extension TimeTag {
	public init(time: CMTime) {
		let adjust = time.convertScale(1<<30, method: .default)
		let integer = adjust.value / .init(adjust.timescale)
		let fraction = adjust.value % .init(adjust.timescale)
		rawValue = .init(integer) << 32 + .init(fraction) << 2
	}
}
extension CMTime {
	public init(_ time: TimeTag) { // 31 -> (2), 32 -> (1), 33 -> (1)
		let factor = max(3, gcd(time.rawValue, 1 << 32))
		self.init(value: .init(time.rawValue / factor), timescale: .init((1 << 32) / factor))
	}
}
