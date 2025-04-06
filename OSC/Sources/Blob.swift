//
//  Blob.swift
//  MUCE
//
//  Created by Kota on 3/31/R7.
//
import typealias Foundation.Data
public typealias Blob = Data
extension RangeReplaceableCollection<UInt8> {
	@inlinable
	mutating func pop<T: BitwiseCopyable>() -> Optional<T> {
		pop(count: MemoryLayout<T>.size)
			.flatMap {
				$0.withContiguousStorageIfAvailable {
					UnsafeRawBufferPointer($0).loadUnaligned(as: T.self)
				}
			}
	}
	@inlinable
	@discardableResult
	mutating func pop(count: Int) -> Optional<SubSequence> {
		switch prefix(count) {
		case let slice where slice.count == count:
			defer {
				trimPrefix(slice)
			}
			return.some(slice)
		default:
			return.none
		}
	}
	@inlinable
	mutating func pop(until value: Element) -> Optional<SubSequence> {
		firstIndex(of: value)
			.map(prefix(upTo:))
			.map {
				trimPrefix($0)
				return $0
			}
	}
}
