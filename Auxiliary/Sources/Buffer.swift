//
//  Buffer.swift
//  MUCE
//
//  Created by Kota on 5/17/R7.
//
import Darwin
import struct Foundation.POSIXError
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
public struct Buffer<Element: BitwiseCopyable>: Sendable {
	@usableFromInline
	final class Memory: @unchecked Sendable {
		@usableFromInline
		let start: UnsafeMutablePointer<Element>
		@usableFromInline
		let count: Int
		@usableFromInline
		let deallocator: @convention(c) (UnsafeMutableRawPointer, Int) -> Void
		@inlinable
		init(start: UnsafeMutablePointer<Element>, count: Int, deallocator: @convention(c) (UnsafeMutableRawPointer, Int) -> Void) {
			self.start = start
			self.count = count
			self.deallocator = deallocator
		}
		@inlinable
		deinit {
			deallocator(start, count * MemoryLayout<Element>.stride)
		}
	}
	@usableFromInline
	let memory: Memory
	@usableFromInline
	let bounds: Range<Int>
}
extension Buffer {
	public init(capacity: Int) {
		memory = .init(start: .allocate(capacity: capacity), count: capacity) { start, count in start.deallocate() }
		bounds = 0..<capacity
	}
	public init(_ sc: some Collection<Element>) {
		memory = .init(start: .allocate(capacity: sc.count), count: sc.count) { start, count in start.deallocate() }
		bounds = 0..<UnsafeMutableBufferPointer(start: memory.start, count: memory.count).initialize(fromContentsOf: sc)
	}
	public init(unsafeUninitializedCapacity: Int, initializingWith: (inout UnsafeMutableBufferPointer<Element>, inout Int) throws -> Void) rethrows {
		memory = .init(start: .allocate(capacity: unsafeUninitializedCapacity), count: unsafeUninitializedCapacity) { start, count in start.deallocate() }
		var length = memory.count
		var buffer = UnsafeMutableBufferPointer(start: memory.start, count: memory.count)
		try initializingWith(&buffer, &length)
		bounds = 0..<length
	}
}
extension Buffer {
	public init(at path: String) throws { // readonly, cow mapping
		let descriptor = open(path, O_RDONLY)
		guard 0 <= descriptor else { throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped) }
		defer {
			close(descriptor)
		}
		var stat = stat()
		let count = switch fstat(descriptor, &stat) {
		case 0:
			.init(stat.st_size) / MemoryLayout<Element>.stride
		default:
			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
		}
		switch mmap(.none, count * MemoryLayout<Element>.stride, PROT_READ|PROT_WRITE, MAP_FILE|MAP_PRIVATE, descriptor, .zero) {
		case.none, MAP_FAILED:
			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
		case.some(let start):
			memory = .init(start: start.assumingMemoryBound(to: Element.self), count: count) { munmap($0, $1) }
			bounds = 0..<count
		}
	}
	public init(at path: String, least count: Int) throws { // writable mapping
		let descriptor = open(path, O_RDWR|O_CREAT, S_IWUSR|S_IRUSR|S_IRGRP|S_IROTH)
		guard 0 <= descriptor else { throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped) }
		defer {
			close(descriptor)
		}
		var stat = stat()
		let size = count * MemoryLayout<Element>.stride
		switch fstat(descriptor, &stat) {
		case 0 where size <= stat.st_size:
			break
		case 0 where 0 == ftruncate(descriptor, .init(size)):
			break
		default:
			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
		}
		switch mmap(.none, size, PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, descriptor, .zero) {
		case.none, MAP_FAILED:
			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
		case.some(let start):
			memory = .init(start: start.assumingMemoryBound(to: Element.self), count: count) { munmap($0, $1) }
			bounds = 0..<count
		}
	}
}
extension Buffer: RandomAccessCollection & MutableCollection {
	public var startIndex: Int { bounds.startIndex }
	public var endIndex: Int { bounds.endIndex }
	public var count: Int { bounds.count }
	public subscript(position: Int) -> Element {
		_read {
			yield memory.start[position]
		}
		nonmutating _modify {
			yield &memory.start[position]
		}
	}
	public subscript(bounds: Range<Int>) -> Self {
		get {
			.init(memory: memory, bounds: bounds)
		}
		nonmutating set {
			let length = UnsafeMutableBufferPointer(start: memory.start, count: memory.count)[bounds].update(fromContentsOf: newValue)
			assert(length == bounds.upperBound)
		}
	}
}
extension Buffer {
	public var startPointer: UnsafeMutablePointer<Element> {
		memory.start.advanced(by: bounds.lowerBound)
	}
	public var unsafeMutableBufferPointer: UnsafeMutableBufferPointer<Element> {
		.init(rebasing: UnsafeMutableBufferPointer(start: memory.start, count: memory.count)[bounds])
	}
}
extension Buffer: AccelerateBuffer & AccelerateMutableBuffer {
	public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
		try body(.init(rebasing: UnsafeMutableBufferPointer(start: memory.start, count: memory.count)[bounds]))
	}
	public func withUnsafeMutableBufferPointer<R>(_ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R {
		var memory = UnsafeMutableBufferPointer(rebasing: UnsafeMutableBufferPointer(start: memory.start, count: memory.count)[bounds])
		return try body(&memory)
	}
}
