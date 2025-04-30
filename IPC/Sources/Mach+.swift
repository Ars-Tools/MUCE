//
//  Mach+.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
@preconcurrency import MachO
//@usableFromInline
//@_silgen_name("bootstrap_port")
//let bootstrap_port: mach_port_t
@usableFromInline
@_silgen_name("bootstrap_register")
func bootstrap_register(_: mach_port_t, _: UnsafePointer<CChar>, _: mach_port_t) -> kern_return_t
@usableFromInline
@_silgen_name("bootstrap_look_up")
func bootstrap_look_up(_: mach_port_t, _: UnsafePointer<CChar>, _: Optional<UnsafeMutablePointer<mach_port_t>>) -> kern_return_t
extension Mach {
	public struct Permission: Sendable {
		public typealias RawValue = UInt32
		public let rawValue: RawValue
		public init(rawValue: RawValue = 0) {
			self.rawValue = rawValue
		}
	}
}
extension Mach.Permission: OptionSet {
	public static let RECV = Self(rawValue: MACH_PORT_RIGHT_RECEIVE)
	public static let SEND = Self(rawValue: MACH_PORT_RIGHT_SEND)
}
extension Mach.Port {
	public convenience init(_ permission: Mach.Permission) throws {
		try self.init(permission: permission.rawValue)
	}
}
extension Mach {
	public struct Control: Sendable {
		public typealias RawValue = UInt32
		public let rawValue: RawValue
		public init(rawValue: RawValue = 0) {
			self.rawValue = rawValue
			
		}
	}
}
extension Mach.Control: OptionSet {
	public static let COPYSEND = Self(rawValue: .init(MACH_MSG_TYPE_COPY_SEND))
	public static let MAKESEND = Self(rawValue: .init(MACH_MSG_TYPE_MAKE_SEND))
}
extension Mach.Port {
	@_disfavoredOverload
	@inlinable
	public func insert(control: Mach.Control) -> Result<(), Mach.Error> {
		switch mach_port_insert_right(mach_task_self_, handle, handle, control.rawValue) {
		case KERN_SUCCESS:
			.success(())
		case let status:
			.failure(.init(rawValue: status))
		}
	}
	public func insert(control: Mach.Control) throws (Mach.Error) {
		try insert(control: control).get()
	}
}
extension Mach.Port {
	@_disfavoredOverload
	@inlinable
	public func bind(on bootstrap: String) -> Result<(), Mach.Error> {
		switch bootstrap_register(bootstrap_port, bootstrap, handle) {
		case KERN_SUCCESS:
			.success(())
		case let status:
			.failure(.init(rawValue: status))
		}
	}
	public func bind(on bootstrap: String) throws (Mach.Error) {
		try bind(on: bootstrap).get()
	}
}
extension Mach {
	@_disfavoredOverload
	@inlinable
	public static func Resolve(for bootstrap: String) -> Result<Endpoint, Mach.Error> {
		withUnsafeTemporaryAllocation(of: mach_port_t.self, capacity: 1) {
			switch bootstrap_look_up(bootstrap_port, bootstrap, $0.baseAddress) {
			case KERN_SUCCESS:
				$0.first.map(Result.success) ?? Result.failure(.init(rawValue: KERN_SUCCESS))
			case let status:
				.failure(.init(rawValue: status))
			}
		}
	}
	public static func Resolve(for name: String) throws (Error) -> Endpoint {
		try Resolve(for: name).get()
	}
}
extension Mach {
	@dynamicMemberLookup
	public struct Error {
		public typealias RawValue = mach_error_t
		public let rawValue: RawValue
		public init(rawValue: RawValue = KERN_SUCCESS) {
			self.rawValue = rawValue
		}
	}
}
extension Mach.Error {
	subscript<R>(dynamicMember keyPath: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: keyPath]
	}
}
extension Mach.Error: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: RawValue) {
		rawValue = value
	}
}
extension Mach.Error: Swift.Error {}
extension Mach.Error: CustomStringConvertible {
	public var description: String {
		.init(cString: mach_error_string(rawValue))
	}
}
