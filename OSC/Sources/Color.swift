//
//  Color.swift
//  MUCE
//
//  Created by Kota on 4/1/R7.
//
import typealias CoreImage.CIColor
import protocol Synchronization.AtomicRepresentable
@dynamicMemberLookup
@frozen public struct Color: RawRepresentable & Sendable & BitwiseCopyable & Codable {
	public typealias RawValue = SIMD4<UInt8>
	public var rawValue: RawValue
	public init(rawValue: RawValue) {
		assert(MemoryLayout<RawValue>.size == 4)
		self.rawValue = rawValue
	}
}
extension Color {
	public subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		_read {
			yield rawValue[keyPath: keyPath]
		}
	}
	public subscript<R>(dynamicMember keyPath: WritableKeyPath<RawValue, R>) -> R {
		_read {
			yield rawValue[keyPath: keyPath]
		}
		_modify {
			yield &rawValue[keyPath: keyPath]
		}
	}
}
extension Color {
	public var r: RawValue.Scalar {
		_read {
			yield rawValue.x
		}
		_modify {
			yield &rawValue.x
		}
	}
	public var g: RawValue.Scalar {
		_read {
			yield rawValue.y
		}
		_modify {
			yield &rawValue.y
		}
	}
	public var b: RawValue.Scalar {
		_read {
			yield rawValue.z
		}
		_modify {
			yield &rawValue.z
		}
	}
	public var a: RawValue.Scalar {
		_read {
			yield rawValue.w
		}
		_modify {
			yield &rawValue.w
		}
	}
}
extension Color {
	public init(_ color: CIColor) {
		rawValue = .init(SIMD4<Float64>(.init(color.red),.init(color.green),.init(color.blue),.init(color.alpha)) * 255.0)
	}
}
extension Color: AtomicRepresentable {
	public static func encodeAtomicRepresentation(_ value: consuming Self) -> RawValue {
		value.rawValue
	}
	public static func decodeAtomicRepresentation(_ storage: consuming RawValue) -> Self {
		.init(rawValue: storage)
	}
}
extension CIColor {
	public convenience init(_ color: Color) {
		let color = SIMD4<Float64>(color.rawValue) / 255.0
		self.init(red: .init(color.x), green: .init(color.y), blue: .init(color.z), alpha: .init(color.w))
	}
}
