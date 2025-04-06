//
//  Untitled.swift
//  MUCE
//
//  Created by Kota on 4/2/R7.
//
@_exported @preconcurrency public import CoreMedia
//@_exported @preconcurrency public import typealias CoreMedia.CMTime
//@preconcurrency import typealias CoreMedia.CMTimeValue
//@preconcurrency import typealias CoreMedia.CMTimeScale
//@preconcurrency import typealias CoreMedia.CMTimeRoundingMethod
//@preconcurrency import func CoreMedia.CMTimeAdd
//@preconcurrency import func CoreMedia.CMTimeSubtract
//@preconcurrency import func CoreMedia.CMTimeGetSeconds
//@preconcurrency import func CoreMedia.CMTimeMultiply
//@preconcurrency import func CoreMedia.CMTimeMultiplyByRatio
//@preconcurrency import func CoreMedia.CMTimeAbsoluteValue
@preconcurrency import func Darwin.modf
extension CMTime {
	@inlinable
	public init(duration: Swift.Duration) {
		let (seconds, attoseconds) = duration.components
		let factor = gcd(1_000_000_000_000_000_000, attoseconds)
		let scale = 1_000_000_000_000_000_000 / factor
		self.init(value: seconds * scale + attoseconds / factor , timescale: .init(scale))
	}
}
extension Duration {
	public init(_ time: CMTime) {
		precondition(time.isNumeric)
		let integer = time.value / .init(time.timescale)
		let fraction = time.value % .init(time.timescale)
		let factor = gcd(1_000_000_000_000_000_000, CMTimeValue(time.timescale))
		let multiplier = 1_000_000_000_000_000_000 / factor
		let divisor = CMTimeValue(time.timescale) / factor
		self.init(secondsComponent: integer, attosecondsComponent: fraction * multiplier / divisor)
	}
}
extension Sequence {
	@inlinable
	func foldr<Result>(_ initialResult: Result, _ nextPartialResult: (Result, Element) throws -> Result) rethrows -> Result {
		try withoutActuallyEscaping(nextPartialResult) { nextPartialResult in
			try reduce({$0} as (Result) throws -> Result) { (partialResult, element) in
				{ try partialResult(nextPartialResult($0, element)) }
			} (initialResult)
		}
	}
}
extension CMTime {
	@inlinable
	@inline(__always)
	public func quantise(by period: CMTime, rounding method: CMTimeRoundingMethod = .default) -> CMTime {
		guard isNumeric, period.isNumeric else { return.invalid }
		switch (Int128(value) * Int128(period.timescale), Int128(timescale) * Int128(period.value)) {
		case(.zero,.zero):
			return.indefinite
		case(0..., .zero):
			return.positiveInfinity
		case(...0, .zero):
			return.negativeInfinity
		case(let n,let d):
			switch method {
			case.roundHalfAwayFromZero,.quickTime:
				let r = mod(n, d) + d / 2 + d
				let p = n - mod(r, d) + d / 2
				return CMTimeMultiply(period, multiplier: .init(div(p, d)))
			case.roundAwayFromZero:
				let r = mod(n, d)
				let q = n - mod(d + r, d)
				let p = n + mod(d - r, d)
				return CMTimeMultiply(period, multiplier: .init(div(p, d) + div(q, d) - div(n, d)))
			case.roundTowardNegativeInfinity:
				let q = n - mod(mod(n, d) + d, d)
				return CMTimeMultiply(period, multiplier: .init(div(q, d)))
			case.roundTowardPositiveInfinity:
				let p = n + mod(d - mod(n, d), d)
				return CMTimeMultiply(period, multiplier: .init(div(p, d)))
			case.roundTowardZero:
				return CMTimeMultiply(period, multiplier: .init(div(n, d)))
			@unknown default:
				fatalError()
			}
		}
	}
}
extension CMTime {
	@inlinable
	@inline(__always)
	public func times(of amount: CMTime, rounding method: Optional<CMTimeRoundingMethod> = .none) -> (count: Int, remainder: CMTime) {
		guard isNumeric, amount.isNumeric else { return (0, .invalid) }
		switch (Int128(value) * Int128(amount.timescale), Int128(timescale) * Int128(amount.value)) {
		case(.zero,.zero):
			return (0, .indefinite)
		case(...0, .zero):
			return (0, .negativeInfinity)
		case(0..., .zero):
			return (0, .positiveInfinity)
		case(let s,let t):
			let n = s * t.signum()
			let d = abs(t)
			let (q, r) = n.quotientAndRemainder(dividingBy: d)
			switch method {
			case.none:
				let g = gcd(r, d)
				return (Int(q), .init(value: .init(div(r, g)), timescale: .init(div(d, g))))
			case.some(.roundHalfAwayFromZero),.some(.quickTime):
//				return (Int(q + r.signum()), .zero)
				return (Int(d.magnitude < r.magnitude * 2 ? r.signum() + q : q), .zero)
			case.some(.roundAwayFromZero):
				return (Int(q + r.signum()), .zero)
			case.some(.roundTowardNegativeInfinity):
				return (Int(q + min(0, r.signum())), .zero)
			case.some(.roundTowardPositiveInfinity):
				return (Int(q + max(0, r.signum())), .zero)
			case.some(.roundTowardZero):
				return (Int(n/d), .zero)
			@unknown default:
				fatalError()
			}
		}
	}
}
//extension CMTime {
//	@inline(__always)
//	@inlinable
//	var simplified: CMTime {
//		let factor = CMTimeValue(gcd(value.magnitude, .init(timescale.magnitude)))
//		return.init(value: value / factor, timescale: .init(.init(timescale) / factor))
//	}
//}
public func CMTimeDivApprox(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
	assert(CMTimeValue.self == Int64.self)
	assert(CMTimeScale.self == Int32.self)
	guard lhs.isValid, rhs.isValid else { return.invalid }
	let n = Int128(lhs.value) * Int128(rhs.timescale)
	let d = Int128(lhs.timescale) * Int128(rhs.value)
	switch abs(gcd(n, d)) {
	case.zero:
		return.indefinite
	case let f:
		let value = n / f
		let scale = d / f
		assert(0 < scale)
		let ratio = 1 + (scale-1)/(1<<31)
		return.init(value: .init(value / ratio), timescale: .init(scale / ratio))
	}
}
public func CMTimeModApprox(_ lhs: CMTime, _ rhs: CMTime) -> CMTime {
	assert(CMTimeValue.self == Int64.self)
	assert(CMTimeScale.self == Int32.self)
	guard lhs.isValid, rhs.isValid else { return.invalid }
	let l = Int128(lhs.value) * Int128(rhs.timescale)
	let r = Int128(lhs.timescale) * Int128(rhs.value)
	let n = mod(l, r)
	let d = Int128(lhs.timescale) * Int128(rhs.timescale)
	switch abs(gcd(n, d)) {
	case.zero:
		return.indefinite
	case let f:
		let value = n / f
		let scale = d / f
		assert(0 < scale)
		let ratio = 1 + (scale-1)/(1<<31)
		return.init(value: .init(value / ratio), timescale: .init(scale / ratio))
	}
}
extension CMTime: @retroactive ExpressibleByIntegerLiteral {
	public init(integerLiteral value: CMTimeValue) {
		self.init(value: value, timescale: 1)
	}
}
extension CMTime: @retroactive ExpressibleByFloatLiteral {
	public init<R: BinaryFloatingPoint>(approximate value: R, truncation length: Int = R.significandBitCount.squareRoot, ε: R = .ulpOfOne.squareRoot()) {
		typealias N = Int128
		let continuedFractionSequence = sequence(state: value) {
			guard $0.isNormal else { return.none }
			let (n, r) = modf($0)
			$0 = ε < r.magnitude ? 1 / r : 0
			return N(exactly: n)
		} as UnfoldSequence<N, R>
		let (p, q) = continuedFractionSequence.prefix(length).foldr((.zero as N, .zero as N)) {
			$0.1 == .zero ? ($1, 1) : $0.0 == .zero ? ($1.signum(), 0) : ($0.0 * $1 + $0.1, $0.0)
		}
		assert(CMTimeScale.self == Int32.self)
		assert(gcd(p, q).magnitude == 1)
		switch (p, q) {
		case(.zero,.zero):
			self = .indefinite
		case(...0, .zero):
			self = .negativeInfinity
		case(0..., .zero):
			self = .positiveInfinity
		case(let p,let q):
			let n = p * q.signum()
			let d = abs(q)
			let r = 1 + ( d - 1 ) / ( 1 << 31 )
			self.init(value: .init(n / r), timescale: .init(d / r))
		}
	}
	public init(floatLiteral value: FloatLiteralType) {
		self = if value.isZero {
			.zero
		} else if value.isSignalingNaN {
			.invalid
		} else if value.isNaN {
			.indefinite
		} else if value.isInfinite, case(.plus) = value.sign {
			.positiveInfinity
		} else if value.isInfinite, case(.minus) = value.sign {
			.negativeInfinity
		} else {
			.init(approximate: value)
		}
	}
}
extension CMTime: @retroactive @unchecked Sendable, @retroactive AdditiveArithmetic, @retroactive InstantProtocol, @retroactive DurationProtocol {
	public typealias Duration = Self
	public func advanced(by duration: Self) -> Self {
		CMTimeAdd(self, duration)
	}
	public func duration(to other: Self) -> Self {
		CMTimeSubtract(other, self)
	}
//	public static func + (lhs: CMTime, rhs: CMTime) -> CMTime {
//		CMTimeAdd(lhs, rhs)
//	}
//	public static func - (lhs: CMTime, rhs: CMTime) -> CMTime {
//		CMTimeSubtract(lhs, rhs)
//	}
	public static func * (lhs: Self, rhs: Int) -> Self {
		CMTimeMultiply(lhs, multiplier: .init(rhs))
	}
	public static func / (lhs: Self, rhs: Int) -> Self {
		CMTimeMultiplyByRatio(lhs, multiplier: 1, divisor: .init(rhs))
	}
	public static func / (lhs: Self, rhs: Self) -> Float64 {
		CMTimeGetSeconds(lhs) / CMTimeGetSeconds(rhs)
	}
}
