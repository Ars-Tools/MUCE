//
//  MIDIMessage.swift
//  MUCE
//
//  Created by Kota on 4/1/R7.
//
import typealias CoreMIDI.MIDIMessage_32
import protocol Synchronization.AtomicRepresentable
@dynamicMemberLookup
@frozen public struct MIDIMessage: RawRepresentable & Sendable & BitwiseCopyable & Codable {
	public typealias RawValue = MIDIMessage_32
	public var rawValue: RawValue
	public init(rawValue: RawValue) {
		assert(MemoryLayout<RawValue>.size == 4)
		self.rawValue = rawValue
	}
}
//extension MIDIMessage {
//	public var port: UInt8 {
//		_read {
//			yield rawValue.x
//		}
//		_modify {
//			yield &rawValue.x
//		}
//	}
//	public var status: UInt8 {
//		_read {
//			yield rawValue.y
//		}
//		_modify {
//			yield &rawValue.y
//		}
//	}
//	public var data: SIMD2<RawValue.Scalar> {
//		_read {
//			yield rawValue.highHalf
//		}
//		_modify {
//			yield &rawValue.highHalf
//		}
//	}
//}
extension MIDIMessage {
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
extension MIDIMessage: AtomicRepresentable {}
