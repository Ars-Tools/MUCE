//
//  Endpoint.swift
//  MUCE
//
//  Created by Kota on 3/28/R7.
//
import let Darwin.AF_INET
import let Darwin.AF_INET6
import let Darwin.INET_ADDRSTRLEN
import let Darwin.INET6_ADDRSTRLEN
import let Darwin.AI_PASSIVE
import typealias Darwin.in_addr
import typealias Darwin.in6_addr
import typealias Darwin.sockaddr_in
import typealias Darwin.sockaddr_in6
import typealias Darwin.addrinfo
import func Darwin.getaddrinfo
import func Darwin.freeaddrinfo
import typealias Network.IPv4Address
import typealias Network.IPv6Address
import typealias Network.NWEndpoint
import protocol Network.IPAddress
public protocol SocketEndpoint: Sendable, Equatable, Hashable {
	static var family: Int32 { get }
}
extension SocketEndpoint {
	public static func Resolve(for domain: String, type: Int32 = 0, protocol: Int32 = 0) -> Set<Self> {
		var hint = addrinfo(
			ai_flags: AI_PASSIVE,
			ai_family: family,
			ai_socktype: type,
			ai_protocol: `protocol`,
			ai_addrlen: 0,
			ai_canonname: .none,
			ai_addr: .none,
			ai_next: .none
		)
		var head: UnsafeMutablePointer<addrinfo>?
		guard getaddrinfo(domain, nil, &hint, &head) == 0 else { return.init() }
		defer {
			freeaddrinfo(head)
		}
		return.init(sequence(first: head) {
			$0.map(\.pointee.ai_next)
		}.lazy.compactMap {
			$0.flatMap(\.pointee)
		}.lazy.compactMap {
			UnsafeRawBufferPointer(start: $0.ai_addr, count: .init($0.ai_addrlen))
				.bindMemory(to: Self.self).first
		})
	}
}
extension IPv4Address {
	public var in_addr: in_addr {
		rawValue.withUnsafeBytes {
			$0.load(as: Darwin.in_addr.self)
		}
	}
}
extension IPv6Address {
	public var in_addr: in6_addr {
		rawValue.withUnsafeBytes {
			$0.load(as: Darwin.in6_addr.self)
		}
	}
}
public protocol IPEndpoint<Address>: SocketEndpoint {
	associatedtype Address: IPAddress & Equatable
	init(addr: Address, port: NWEndpoint.Port)
	var addr: Address { get }
	var port: NWEndpoint.Port { get }
}
public typealias IPv4Endpoint = sockaddr_in
public typealias IPv6Endpoint = sockaddr_in6
extension IPv4Endpoint: @retroactive Hashable {
	public func hash(into hasher: inout Hasher) {
		withUnsafeBytes(of: self) {
			$0.forEach { $0.hash(into: &hasher) }
		}
	}
}
extension IPv6Endpoint: @retroactive Hashable {
	public func hash(into hasher: inout Hasher) {
		withUnsafeBytes(of: self) {
			$0.forEach { $0.hash(into: &hasher) }
		}
	}
}
extension IPv4Endpoint: @unchecked @retroactive Sendable, IPEndpoint  {
	public static let family: Int32 = AF_INET
	public init(addr: IPv4Address, port: NWEndpoint.Port) {
		self.init(
			sin_len: .init(INET_ADDRSTRLEN),
			sin_family: .init(type(of: self).family),
			sin_port: port.rawValue.bigEndian,
			sin_addr: addr.rawValue.withUnsafeBytes { $0.load(as: in_addr.self) },
			sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
		)
	}
	public var addr: IPv4Address {
		withUnsafeBytes(of: sin_addr) {
			.init(.init($0), .none).unsafelyUnwrapped
		}
	}
	@inlinable
	public var port: NWEndpoint.Port {
		.init(rawValue: .init(bigEndian: sin_port)).unsafelyUnwrapped
	}
	@inlinable
	public var host: NWEndpoint.Host {
		.ipv4(addr)
	}
	@inlinable
	public var nwEndpoint: NWEndpoint {
		.hostPort(host: host, port: port)
	}
	public static func==(lhs: Self, rhs: Self) -> Bool {(
//		lhs.sin_len,
		lhs.sin_family,
		lhs.sin_port,
		lhs.sin_addr.s_addr
	) == (
//		rhs.sin_len,
		rhs.sin_family,
		rhs.sin_port,
		rhs.sin_addr.s_addr
	)}
}
extension IPv4Endpoint: @retroactive CustomStringConvertible {
	public var description: String {
		"\(nwEndpoint)"
	}
}
extension IPv6Endpoint: @retroactive @unchecked Sendable, IPEndpoint {
	public static let family: Int32 = AF_INET6
	public init(addr: IPv6Address, port: NWEndpoint.Port) {
		self.init(
			sin6_len: .init(INET6_ADDRSTRLEN),
			sin6_family: .init(type(of: self).family),
			sin6_port: port.rawValue.bigEndian,
			sin6_flowinfo: 0,
			sin6_addr: addr.rawValue.withUnsafeBytes { $0.load(as: in6_addr.self) },
			sin6_scope_id: 0
		)
	}
	public var addr: IPv6Address {
		withUnsafeBytes(of: sin6_addr) {
			.init(.init($0), .none).unsafelyUnwrapped
		}
	}
	@inlinable
	public var port: NWEndpoint.Port {
		.init(rawValue: .init(bigEndian: sin6_port)).unsafelyUnwrapped
	}
	@inlinable
	public var host: NWEndpoint.Host {
		.ipv6(addr)
	}
	@inlinable
	public var nwEndpoint: NWEndpoint {
		.hostPort(host: host, port: port)
	}
	public static func==(lhs: Self, rhs: Self) -> Bool {(
//		lhs.sin6_len,
		lhs.sin6_family,
		lhs.sin6_port,
		unsafeBitCast(lhs.sin6_addr, to: SIMD4<UInt32>.self)
	) == (
//		rhs.sin6_len,
		rhs.sin6_family,
		rhs.sin6_port,
		unsafeBitCast(rhs.sin6_addr, to: SIMD4<UInt32>.self)
	)}
}
extension IPv6Endpoint: @retroactive CustomStringConvertible {
	public var description: String {
		"\(nwEndpoint)"
	}
}
