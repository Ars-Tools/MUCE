//
//  Tcp.swift
//  MUCE
//
//  Created by Kota on 3/28/R7.
//
import func Darwin.socket
import func Darwin.close
import func Darwin.bindresvport_sa
import func Darwin.listen
import func Darwin.accept
import func Darwin.connect
import func Darwin.send
import func Darwin.recv
import func Darwin.getpeername
import let Darwin.errno
import let Darwin.SOCK_STREAM
import let Darwin.SOL_SOCKET
import let Darwin.SO_KEEPALIVE
import let Darwin.SOMAXCONN
import let Darwin.IPPROTO_TCP
import typealias Darwin.sockaddr
import typealias Darwin.socklen_t
import typealias Network.NWError
import typealias Synchronization.Mutex
@preconcurrency import typealias Dispatch.DispatchQueue
@preconcurrency import typealias Dispatch.DispatchSource
@preconcurrency import typealias Dispatch.DispatchSemaphore
public enum Tcp {}
extension Tcp {
	public final class Socket<Endpoint: IPEndpoint> : Sendable {
		@usableFromInline
		let handle: Int32
		@inlinable
		init(handle fileDescriptor: Int32) {
			precondition(0 <= fileDescriptor, "invalid fileDescriptor (\(fileDescriptor))")
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
extension Tcp {
	public static func Resolve<Endpoint: IPEndpoint>(for domain: String) -> Set<Endpoint> {
		Endpoint.Resolve(for: domain, type: SOCK_STREAM, protocol: IPPROTO_TCP)
	}
}
extension Tcp.Socket: Socket {}
extension Tcp.Socket {
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func send(data: UnsafeBufferPointer<UInt8>) -> Result<Int, NWError> {
		switch Darwin.send(handle, data.baseAddress, data.count, 0) {
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
		switch Darwin.send(handle, data, data.count, 0) {
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
//			Task {
//				do {
//					for try await var packet in stream {
//						while !packet.isEmpty {
//							try packet.removeFirst(packet.withContiguousStorageIfAvailable(send(data:)) ?? send(data: Array(packet)))
//						}
//						future.yield()
//					}
//					future.finish()
//				} catch {
//					future.finish(throwing: error)
//				}
//			}
		}
	}
}
extension Tcp.Socket {
	@_disfavoredOverload
	@inlinable
	public func recv(count: Int) -> Result<Array<UInt8>, NWError> {
		let data = Array<UInt8>(unsafeUninitializedCapacity: count) {
			$1 = Darwin.recv(handle, $0.baseAddress, $0.count, 0)
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
				case.finished:
					break
				case.cancelled:
					break
				@unknown default:
					break
				}
				if !source.isCancelled {
					source.cancel() // strong capture
				}
			}
			source.setEventHandler { [weak source] in
				guard let source else { return }
				do throws(NWError) {
					switch source.data {
					case ...0:
						source.cancel()
					case let count:
						try future.yield(self.recv(count: .init(count)))
					}
				} catch {
					future.finish(throwing: error)
				}
			}
			source.setCancelHandler {
				future.finish()
			}
			source.resume()
		}
	}
}
extension Tcp.Socket {
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func shutdown(scope: Shutdown) -> Result<(), NWError> {
		scope.apply(handle: handle) == 0 ?
			.success(()) :
			.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
	}
	public func shutdown(scope: Shutdown) throws(NWError) {
		try shutdown(scope: scope).get()
	}
}
extension Tcp {
	private static func connect(_ descriptor: Int32, _ endpoint: some IPEndpoint) -> Int32 {
		withUnsafeBytes(of: endpoint) {
			Darwin.connect(descriptor, $0.assumingMemoryBound(to: sockaddr.self).baseAddress, .init($0.count))
		}
	}
	public static func Connect<Endpoint: IPEndpoint>(to endpoint: Endpoint) throws(NWError) -> Socket<Endpoint> {
		switch Darwin.socket(Endpoint.family, SOCK_STREAM, IPPROTO_TCP) {
		case let fileDescriptor where 0 <= fileDescriptor && 0 == connect(fileDescriptor, endpoint):
			return.init(handle: fileDescriptor)
		case let fileDescriptor where 0 <= fileDescriptor && 0 == close(fileDescriptor):
			fallthrough
		default:
			throw.posix(.init(rawValue: errno).unsafelyUnwrapped)
		}
	}
}
extension Tcp {
	private static func bind(_ descriptor: Int32, _ endpoint: some IPEndpoint) -> Int32 {
		withUnsafeBytes(of: endpoint) {
			Darwin.bindresvport_sa(descriptor, .init(mutating: $0.assumingMemoryBound(to: sockaddr.self).baseAddress))
		}
	}
	public static func Incoming<Endpoint: IPEndpoint>(on endpoint: Endpoint, with queue: Optional<DispatchQueue> = .none, listen count: Int32 = SOMAXCONN) -> some AsyncSequence<(Socket<Endpoint>, Endpoint), any Error> & Sendable {
		AsyncThrowingStream { future in
			switch Darwin.socket(Endpoint.family, SOCK_STREAM, IPPROTO_TCP) {
			case let fileDescriptor where 0 <= fileDescriptor && 0 == bind(fileDescriptor, endpoint) && 0 == listen(fileDescriptor, count):
				let source = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor)
				future.onTermination = {
					switch $0 {
					case.cancelled:
						break
					case.finished:
						break
					@unknown default:
						break
					}
					source.cancel()
				}
				source.setEventHandler { [weak source] in
					guard let source else { return }
					assert(source.data == 1)
					withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Endpoint>.stride + MemoryLayout<socklen_t>.size,
												  alignment: MemoryLayout<Endpoint>.alignment) {
						$0.storeBytes(of: socklen_t(MemoryLayout<Endpoint>.size),
									  toByteOffset: MemoryLayout<Endpoint>.stride,
									  as: socklen_t.self)
						switch accept(fileDescriptor,
									  $0.assumingMemoryBound(to: sockaddr.self).baseAddress,
									  $0.dropFirst(MemoryLayout<Endpoint>.stride).assumingMemoryBound(to: socklen_t.self).baseAddress) {
						case ..<0:
							future.finish(throwing: NWError.posix(.init(rawValue: errno).unsafelyUnwrapped))
						case let fileDescriptor:
							future.yield((.init(handle: fileDescriptor), $0.load(as: Endpoint.self)))
						}
					}
				}
				source.setCancelHandler { [weak source] in
					guard let source else { return }
					assert(source.data == 0)
					switch close(fileDescriptor) {
					case 0:
						break
					default:
						break
					}
				}
				source.resume()
			case let fileDescriptor where 0 <= fileDescriptor && 0 == close(fileDescriptor):
				fallthrough
			default:
				future.finish(throwing: NWError.posix(.init(rawValue: errno).unsafelyUnwrapped))
			}
		}
	}
}
extension Tcp.Socket {
	public var keepalive: Bool {
		get {
			switch getsockopt(level: SOL_SOCKET, name: SO_KEEPALIVE) as Result<Int32, NWError> {
			case.success(1...):
				true
			default:
				false
			}
		}
		set {
			switch setsockopt(level: SOL_SOCKET, name: SO_KEEPALIVE, value: newValue ? 1 : 0 as Int32) {
			case.success:
				break
			case.failure(let error):
				log(info: error)
			}
		}
	}
}
extension Tcp.Socket {
	@inlinable
	func getpeer() -> Result<Endpoint, NWError> {
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Endpoint>.stride + MemoryLayout<socklen_t>.size,
									  alignment: MemoryLayout<Endpoint>.alignment) {
			$0.storeBytes(of: socklen_t(MemoryLayout<Endpoint>.size),
						  toByteOffset: MemoryLayout<Endpoint>.stride,
						  as: socklen_t.self)
			return Darwin.getpeername(handle,
									  $0.assumingMemoryBound(to: sockaddr.self).baseAddress,
									  $0.dropFirst(MemoryLayout<Endpoint>.stride).assumingMemoryBound(to: socklen_t.self).baseAddress) == 0 ?
				.success($0.load(as: Endpoint.self)) :
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
		}
	}
	public var peer: Endpoint {
		get throws(NWError) {
			try getpeer().get()
		}
	}
}
