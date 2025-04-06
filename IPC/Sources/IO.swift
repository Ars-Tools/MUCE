//
//  IO.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
import func Darwin.open
import func Darwin.pipe
import func Darwin.read
import func Darwin.write
import func Darwin.dup
import func Darwin.close
import let Darwin.errno
import let Darwin.STDIN_FILENO
import let Darwin.STDOUT_FILENO
import let Darwin.STDERR_FILENO
import typealias Network.NWError
import typealias Synchronization.Mutex
@preconcurrency import typealias Dispatch.DispatchQueue
@preconcurrency import typealias Dispatch.DispatchSource
@preconcurrency import typealias Dispatch.DispatchSemaphore
protocol Com: Sendable, Identifiable, Hashable, AnyObject {
	var handle: Int32 { get }
	init(handle: Int32)
}
extension Com {
	public init(_ object: Self) throws (NWError) { // same behavior and different object
		switch dup(object.handle) {
		case ..<0:
			throw.posix(.init(rawValue: errno).unsafelyUnwrapped)
		case let fileDescriptor:
			self.init(handle: fileDescriptor)
		}
	}
	public static func==(lhs: Self, rhs: Self) -> Bool {
		lhs.handle == rhs.handle
	}
	public func hash(into hasher: inout Hasher) {
		handle.hash(into: &hasher)
	}
	public var id: Int32 { handle }
}
public enum IO {
	public final class Reader: Com {
		@usableFromInline
		let handle: Int32
		public init(handle fileDescriptor: Int32) {
			handle = fileDescriptor
		}
		deinit {
			switch close(handle) {
			case.zero:
				break
			default:
				log(debug: .posix(.init(rawValue: errno).unsafelyUnwrapped))
			}
		}
	}
	public final class Writer: Com {
		@usableFromInline
		let handle: Int32
		public init(handle fileDescriptor: Int32) {
			handle = fileDescriptor
		}
		deinit {
			switch close(handle) {
			case.zero:
				break
			default:
				log(debug: .posix(.init(rawValue: errno).unsafelyUnwrapped))
			}
		}
	}
}
extension IO.Reader {
	@_disfavoredOverload
	@inlinable
	public func recv(count: Int) -> Result<Array<UInt8>, NWError> {
		let data = Array<UInt8>(unsafeUninitializedCapacity: count) {
			$1 = Darwin.read(handle, $0.baseAddress, $0.count)
		}
		return switch data.count {
		case ..<0:
			.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		default:
			.success(data)
		}
	}
	public func recv(count: Int) throws(NWError) -> Array<UInt8> {
		try recv(count: count).get()
	}
	public func recv(on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<Array<UInt8>, any Error> & Sendable {
		AsyncThrowingStream { future in
			let source = DispatchSource.makeReadSource(fileDescriptor: handle, queue: queue)
			future.onTermination = {
				switch $0 {
				case.cancelled:
					break
				case.finished:
					break
				@unknown default:
					break
				}
				source.cancel() // strong capture
			}
			source.setEventHandler { [weak source] in
				do throws (NWError) {
					guard let source else { throw NWError.posix(.ENOENT) }
					switch source.data {
					case ...0:
						future.finish()
					case let count:
						try future.yield(self.recv(count: .init(count)))
					}
				} catch {
					future.finish(throwing: error)
				}
			}
			source.resume()
		}
	}
}
extension IO.Writer {
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func send(data: UnsafeBufferPointer<UInt8>) -> Result<Int, NWError> {
		switch write(handle, data.baseAddress, data.count) {
		case ..<0:
			.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		case let count:
			.success(count)
		}
	}
	@discardableResult
	public func send(data: UnsafeBufferPointer<UInt8>) throws(NWError) -> Int {
		try send(data: data).get()
	}
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func send(data: Array<UInt8>) -> Result<Int, NWError> {
		switch write(handle, data, data.count) {
		case ..<0:
			.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		case let count:
			.success(count)
		}
	}
	@discardableResult
	public func send(data: Array<UInt8>) throws(NWError) -> Int {
		try send(data: data).get()
	}
	public func send(stream: some AsyncSequence<some RangeReplaceableCollection<UInt8> & Sendable, any Error> & Sendable, on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<Void, any Error> & Sendable {
		AsyncThrowingStream { future in
			let buffer = Mutex<ArraySlice<UInt8>>(.init())
			let source = DispatchSource.makeWriteSource(fileDescriptor: handle, queue: queue)
			let cancel = DispatchSemaphore(value: 0)
			future.onTermination = {
				switch $0 {
				case.cancelled:
					break
				case.finished:
					break
				@unknown default:
					break
				}
				buffer.withLock {
					if !source.isCancelled {
						source.cancel()
					}
					$0.removeAll()
				}
				cancel.wait() // avoid bug
			}
			source.setEventHandler(flags: .barrier) { [weak source] in
				buffer.withLock {
					guard let source, 0 < source.data else { return }
					switch $0.isEmpty {
					case true:
						source.suspend()
					case false:
						do {
							try $0.removeFirst($0.prefix(.init(source.data)).withUnsafeBufferPointer(self.send(data:)))
							future.yield()
						} catch {
							future.finish(throwing: error)
						}
					}
				}
			}
			source.setCancelHandler(flags: .barrier) { [weak source] in
				buffer.withLock {
					guard let source else { return }
					source.resume() // avoid bug
					$0.removeAll()
				}
				cancel.signal()
			}
			Task {
				do {
					for try await packet in stream where [!packet.isEmpty, !Task.isCancelled].allSatisfy(\.self) {
						buffer.withLock {
							$0.append(contentsOf: packet)
							if !source.isCancelled {
								source.resume()
							}
						}
					}
					future.finish()
				} catch {
					future.finish(throwing: error)
				}
			}
		}
	}
}
extension IO {
	public enum Std {
		public static let In = Reader(handle: STDIN_FILENO) // Never close
		public static let Out = Writer(handle: STDOUT_FILENO) // Never close
		public static let Err = Writer(handle: STDERR_FILENO) // Never close
	}
	public static func Pipe() throws (NWError) -> (Reader, Writer) {
		let result = Array<Int32>(unsafeUninitializedCapacity: 2) {
			$1 = pipe($0.baseAddress) == 0 ? $0.count : 0
		}
		let reader = result.first.map(Reader.init(handle:))
		let writer = result.last.map(Writer.init(handle:))
		guard let reader, let writer else {
			throw.posix(.init(rawValue: errno).unsafelyUnwrapped)
		}
		return (reader, writer)
	}
}
extension IO {
	public enum Mach {
		
	}
}
