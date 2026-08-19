//
//  Udp.swift
//  MUCE
//
//  Created by Kota on 3/28/R7.
//
import func Darwin.socket
import func Darwin.close
import func Darwin.shutdown
import func Darwin.bindresvport_sa
import func Darwin.sendto
import func Darwin.recvfrom
import let Darwin.errno
import let Darwin.SOCK_DGRAM
import let Darwin.IPPROTO_UDP
import let Darwin.IPPROTO_IP
import let Darwin.IPPROTO_IPV6
import let Darwin.IP_ADD_MEMBERSHIP
import let Darwin.IP_DROP_MEMBERSHIP
import let Darwin.IP_MULTICAST_TTL
import let Darwin.IPV6_JOIN_GROUP
import let Darwin.IPV6_LEAVE_GROUP
import let Darwin.IPV6_MULTICAST_HOPS
import typealias Darwin.in_addr
import typealias Darwin.in6_addr
import typealias Darwin.timeval
import typealias Darwin.ip_mreq
import typealias Darwin.ipv6_mreq
import typealias Darwin.sockaddr
import typealias Darwin.socklen_t
import typealias Synchronization.Mutex
import enum Network.NWError
@preconcurrency import typealias Dispatch.DispatchQueue
@preconcurrency import typealias Dispatch.DispatchSource
@preconcurrency import typealias Dispatch.DispatchSemaphore
import unistd
public enum Udp {}
extension Udp {
	public final class Socket<Endpoint: IPEndpoint>: Sendable {
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
extension Udp {
	public static func Resolve<Endpoint: IPEndpoint>(for domain: String) -> Set<Endpoint> {
		Endpoint.Resolve(for: domain, type: SOCK_DGRAM, protocol: IPPROTO_UDP)
	}
}
extension Udp.Socket: Socket {}
extension Udp.Socket {
	public convenience init() throws (NWError) {
		switch socket(Endpoint.family, SOCK_DGRAM, IPPROTO_UDP) {
		case let fileDescriptor where 0 <= fileDescriptor:
			self.init(handle: fileDescriptor)
		default:
			throw.posix(.init(rawValue: errno).unsafelyUnwrapped)
		}
	}
	public convenience init(on endpoint: Endpoint) throws (NWError) {
		try self.init()
		try bind(on: endpoint)
	}
}
extension Udp.Socket {
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func bind(on endpoint: Endpoint) -> Result<(), NWError> {
		withUnsafeBytes(of: endpoint) { bindresvport_sa(handle, .init(mutating: $0.assumingMemoryBound(to: sockaddr.self).baseAddress)) } == 0 ?
			.success(()) :
			.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
	}
	public func bind(on endpoint: Endpoint) throws(NWError) {
		try bind(on: endpoint).get()
	}
}
extension Udp.Socket {
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func send(data: UnsafeBufferPointer<UInt8>, to endpoint: Endpoint) -> Result<Int, NWError> {
		withUnsafeBytes(of: endpoint) {
			switch Darwin.sendto(handle, data.baseAddress, data.count, 0, $0.assumingMemoryBound(to: sockaddr.self).baseAddress, .init($0.count)) {
			case ..<0:
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
			case let count:
				.success(count)
			}
		}
	}
    @inlinable
	@discardableResult
	public func send(data: UnsafeBufferPointer<UInt8>, to endpoint: Endpoint) throws(NWError) -> Int {
		try send(data: data, to: endpoint).get()
	}
	@_disfavoredOverload
	@inlinable
	@discardableResult
	public func send(data: Array<UInt8>, to endpoint: Endpoint) -> Result<Int, NWError> {
		withUnsafeBytes(of: endpoint) {
			switch Darwin.sendto(handle, data, data.count, 0, $0.assumingMemoryBound(to: sockaddr.self).baseAddress, .init($0.count)) {
			case ..<0:
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
			case let count:
				.success(count)
			}
		}
	}
    @inlinable
	@discardableResult
	public func send(data: Array<UInt8>, to endpoint: Endpoint) throws(NWError) -> Int {
		try send(data: data, to: endpoint).get()
	}
    @inlinable
    public func send(stream: some AsyncSequence<(some RangeReplaceableCollection<UInt8> & Sendable, Endpoint), any Error> & Sendable, on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<(), any Error> & Sendable {
        stream.map { [self] packet, endpoint in
            let count = try packet.withContiguousStorageIfAvailable {
                try send(data: $0, to: endpoint)
            } ?? send(data: Array(packet), to: endpoint)
            assert(count == packet.count, "incomplete datagram error, no way")
        }
	}
}
extension Udp.Socket {
	@_disfavoredOverload
	@inlinable
	public func recv(count: Int) -> Result<(Array<UInt8>, Endpoint), NWError> {
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Endpoint>.stride + MemoryLayout<socklen_t>.size,
									  alignment: MemoryLayout<Endpoint>.alignment) { memory in
			memory.storeBytes(of: socklen_t(MemoryLayout<Endpoint>.size),
							  toByteOffset: MemoryLayout<Endpoint>.stride,
							  as: socklen_t.self)
			let data = Array<UInt8>(unsafeUninitializedCapacity: count) {
				$1 = recvfrom(handle, $0.baseAddress, $0.count, 0,
							  memory.assumingMemoryBound(to: sockaddr.self).baseAddress,
							  memory.dropFirst(MemoryLayout<Endpoint>.stride).assumingMemoryBound(to: socklen_t.self).baseAddress)
			}
			return switch data.count {
			case ..<0:
				.failure(.posix(.init(rawValue: errno).unsafelyUnwrapped))
			default:
				.success((data, memory.load(as: Endpoint.self)))
			}
		}
	}
	public func recv(count: Int) throws(NWError) -> (Array<UInt8>, Endpoint) {
		try recv(count: count).get()
	}
	public func recv(on queue: Optional<DispatchQueue> = .none) -> some AsyncSequence<(Array<UInt8>, Endpoint), any Error> & Sendable {
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
extension Udp.Socket where Endpoint == IPv4Endpoint {
	@_disfavoredOverload
	@discardableResult
	public func join(multicast addr: Endpoint.Address, on interface: Endpoint.Address) -> Result<(), NWError> {
		setsockopt(level: IPPROTO_IP, name: IP_ADD_MEMBERSHIP, value: ip_mreq(
			imr_multiaddr: addr.in_addr,
			imr_interface: interface.in_addr
		))
	}
	public func join(multicast addr: Endpoint.Address, on interface: Endpoint.Address) throws(NWError) {
		try join(multicast: addr, on: interface).get()
	}
	@_disfavoredOverload
	@discardableResult
	public func leave(multicast addr: Endpoint.Address, on interface: Endpoint.Address) -> Result<(), NWError> {
		setsockopt(level: IPPROTO_IP, name: IP_DROP_MEMBERSHIP, value: ip_mreq(
			imr_multiaddr: addr.in_addr,
			imr_interface: interface.in_addr
		))
	}
	public func leave(multicast addr: Endpoint.Address, on interface: Endpoint.Address) throws(NWError) {
		try leave(multicast: addr, on: interface).get()
	}
	public var multicastTTL: Int32 {
		get {
			switch getsockopt(level: IPPROTO_IP, name: IP_MULTICAST_TTL) as Result<Int32, NWError> {
			case.success(let count):
				count
			case.failure:
				0
			}
		}
		set {
			switch setsockopt(level: IPPROTO_IP, name: IP_MULTICAST_TTL, value: newValue) {
			case.success:
				break
			case.failure(let error):
				log(info: error)
			}
		}
	}
	public var name: Endpoint {
		get throws(NWError) {
			try getname().get()
		}
	}
}
//extension Udp.Socket where Endpoint == IPv6Endpoint {
//	@discardableResult
//	public func join(multicast address: Endpoint.Address, via interface: UInt32) -> Result<(), NWError> {
//		setsockopt(level: IPPROTO_IPV6, name: IPV6_JOIN_GROUP, value: ipv6_mreq(
//			ipv6mr_multiaddr: address.rawValue.withUnsafeBytes { $0.load(as: in6_addr.self) },
//			ipv6mr_interface: interface))
//	}
//	@discardableResult
//	public func leave(multicast address: Endpoint.Address, via interface: UInt32) -> Result<(), NWError> {
//		setsockopt(level: IPPROTO_IPV6, name: IPV6_LEAVE_GROUP, value: ipv6_mreq(
//			ipv6mr_multiaddr: address.rawValue.withUnsafeBytes { $0.load(as: in6_addr.self) },
//			ipv6mr_interface: interface))
//	}
//	@discardableResult
//	public func set(multicastTTL value: UInt32) -> Result<(), NWError> {
//		setsockopt(level: IPPROTO_IPV6, name: IPV6_MULTICAST_HOPS, value: value)
//	}
//}
