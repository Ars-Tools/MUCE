//
//  Collection+.swift
//  MUCE
//
//  Created by Kota on 4/9/R7.
//
extension Collection where Element == UInt8, SubSequence == Self {
	mutating func popElement<T: FixedWidthInteger & BitwiseCopyable>() -> Optional<T> {
		popPayload(count: MemoryLayout<T>.size).flatMap {
			$0.withContiguousStorageIfAvailable {
				UnsafeRawBufferPointer($0).loadUnaligned(as: T.self)
			}
		}
	}
	mutating func popPayload(count: Int) -> Optional<SubSequence> {
		switch prefix(count) {
		case let prefix where prefix.count == count:
			trimPrefix(prefix)
			return.some(prefix)
		default:
			return.none
		}
	}
}
