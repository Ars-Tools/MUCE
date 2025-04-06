//
//  Handler.swift
//  MUCE
//
//  Created by Kota on 4/1/R7.
//
import protocol IPC.IPEndpoint
import typealias IPC.Udp
import typealias IPC.Tcp
public protocol Handler<Schema, Endpoint>: Sendable {
	associatedtype Schema: Sendable
	associatedtype Endpoint: Sendable
	@discardableResult
	func callAsFunction(schema: Schema, arguments: Array<Argument>, timestamp: TimeTag, endpoint: Endpoint) async throws -> Optional<Packet>
}
extension Handler where Schema == String {
	@inlinable@inline(__always)
	func compress(workgroup: ThrowingTaskGroup<Optional<Packet>, any Error>) async throws -> Optional<Packet> {
		let packets = try await workgroup.compactMap(\.self).reduce(into: []) { $0.append($1) }
		return switch packets.count {
		case ...0:
			.none
		case 1:
			packets.first
		default:
			.some(.Bundle(timestamp: .immediately, packets: packets))
		}
	}
	public func process(stream: some AsyncSequence<(some RangeReplaceableCollection<UInt8> & Sendable, Endpoint), any Error> & Sendable, context: Context = .default) -> some AsyncSequence<(Array<UInt8>, Endpoint), any Error> & Sendable {
		stream.compactMap { packet, endpoint in
			Packet(decode: packet, context: context).map { ($0, endpoint) }
		}.compactMap { packet, endpoint in
			try await withThrowingTaskGroup(of: Optional<Packet>.self) { workgroup in
				for (schema, arguments, timestamp) in packet {
					workgroup.addTask {
						try await callAsFunction(schema: schema, arguments: arguments, timestamp: timestamp, endpoint: endpoint)
					}
				}
				return try await compress(workgroup: workgroup)
			}.map { ($0.encode(), endpoint) }
		}
	}
}
public actor Function<Schema: Sendable, Endpoint: Sendable> {
	@usableFromInline
	typealias RawValue = @Sendable (Schema, Array<Argument>, TimeTag, Endpoint) async throws -> Optional<Packet>
	@usableFromInline
	let rawValue: RawValue
	@inlinable
	init(rawValue: @escaping RawValue) {
		self.rawValue = rawValue
	}
}
extension Function: Handler, Identifiable, Hashable {
	public func callAsFunction(schema: Schema, arguments: Array<Argument>, timestamp: TimeTag, endpoint: Endpoint) async throws -> Optional<Packet> {
		try await rawValue(schema, arguments, timestamp, endpoint)
	}
	public static func==(lhs: Function, rhs: Function) -> Bool {
		lhs.id == rhs.id
	}
	public nonisolated func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
}
public typealias Router<Endpoint> = Dictionary<String, Function<AnyRegexOutput, Endpoint>>
extension Router: Handler where Key == String, Value: Handler, Value.Schema == AnyRegexOutput {
	public typealias Schema = String
	public typealias Endpoint = Value.Endpoint
	public func callAsFunction(schema: String, arguments: Array<Argument>, timestamp: TimeTag, endpoint: Endpoint) async throws -> Optional<Packet> {
		let pattern = try Regex(osc: schema)
		return try await withThrowingTaskGroup(of: Optional<Packet>.self) { workgroup in
			forEach { key, value in
				if case.some(let schema) = key.wholeMatch(of: pattern).map(\.output) {
					workgroup.addTask {
						try await value(schema: schema, arguments: arguments, timestamp: timestamp, endpoint: endpoint)
					}
				}
			}
			return try await compress(workgroup: workgroup)
		}
	}
	@discardableResult
	public mutating func dispatch<Endpoint>(for path: String, execute: @escaping @Sendable (AnyRegexOutput, Array<Argument>, TimeTag, Endpoint) async throws -> Optional<Packet>) -> Value where Value == Function<AnyRegexOutput, Endpoint> {
		let element = Value(rawValue: execute)
		updateValue(element, forKey: path)
		return element
	}
}
public typealias Matcher<Endpoint> = Set<Function<String, Endpoint>>
extension Matcher: Handler where Element: Handler, Element.Schema == String {
	public typealias Schema = String
	public typealias Endpoint = Element.Endpoint
	public func callAsFunction(schema: String, arguments: Array<Argument>, timestamp: TimeTag, endpoint: Endpoint) async throws -> Optional<Packet> {
		try await withThrowingTaskGroup(of: Optional<Packet>.self) { workgroup in
			forEach { function in
				workgroup.addTask {
					try await function(schema: schema, arguments: arguments, timestamp: timestamp, endpoint: endpoint)
				}
			}
			return try await compress(workgroup: workgroup)
		}
	}
	@discardableResult
	public mutating func dispatch<Output, Endpoint>(for pattern: Regex<Output>, execute: @escaping @Sendable (Output, Array<Argument>, TimeTag, Endpoint) async throws -> Optional<Packet>) -> Element where Element == Function<String, Endpoint> {
		let element = Element {
			switch $0.wholeMatch(of: pattern).map(\.output) {
			case.some(let output):
				try await execute(output, $1, $2, $3)
			case.none:
				.none
			}
		}
		insert(element)
		return element
	}
}

