//
//  Mach.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
@preconcurrency import Darwin
@preconcurrency import typealias Network.NWError
@preconcurrency import MachO
@preconcurrency import os.log
@preconcurrency import Darwin
@preconcurrency import Dispatch
@preconcurrency import unistd
@preconcurrency import Darwin.Mach
public enum Mach {
	public typealias Endpoint = mach_port_t
	public final class Port: Sendable {
		@usableFromInline
		let handle: mach_port_t
		init(permission right: mach_port_right_t) throws (Mach.Error) {
			let result = withUnsafeTemporaryAllocation(of: mach_port_name_t.self, capacity: 1) {
				switch mach_port_allocate(mach_task_self_, right, $0.baseAddress) {
				case KERN_SUCCESS:
					$0.first.map(Result.success) ?? Result.failure(.init(rawValue: KERN_SUCCESS))
				case let status:
					Result.failure(.init(rawValue: status))
				}
			} as Result<mach_port_t, Mach.Error>
			handle = try result.get()
		}
		deinit {
			switch mach_port_deallocate(mach_task_self_, handle) {
			case KERN_SUCCESS:
				break
			case let status:
				os_log(.debug, "%@", String(cString: mach_error_string(status)))
			}
		}
	}
}
extension Mach.Port {
	
}
extension Mach.Port {
	public func connect(to name: String) {
		
	}
}
extension Mach.Port {
	public func send(data: some RangeReplaceableCollection<UInt8>) -> Result<(), Mach.Error> {
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<mach_msg_header_t>.stride + data.count,
									  alignment: MemoryLayout<mach_msg_header_t>.alignment) {
			switch mach_msg(
				$0.baseAddress?.assumingMemoryBound(to: mach_msg_header_t.self),
				MACH_SEND_MSG,
				.init($0.count),
				0,
				.init(MACH_PORT_NULL),
				.init(MACH_MSG_TIMEOUT_NONE),
				.init(MACH_PORT_NULL)) {
			case KERN_SUCCESS:
				.success(())
			case let status:
				.failure(.init(rawValue: status))
			}
		}
	}
}
extension Mach.Port {
	public func recv(count: Int) -> ArraySlice<UInt8> {
		let buffer = Array<UInt8>(unsafeUninitializedCapacity: MemoryLayout<mach_msg_header_t>.stride + count) {
			$1 = switch mach_msg(
				$0.withMemoryRebound(to: mach_msg_header_t.self, \.baseAddress),
				MACH_RCV_MSG,
				0,
				.init($0.count),
				handle,
				.init(MACH_MSG_TIMEOUT_NONE),
				.init(MACH_PORT_NULL)) {
			case KERN_SUCCESS:
				$0.count
			default:
				0
			}
		}
		return buffer.dropFirst(MemoryLayout<mach_msg_header_t>.stride)
	}
}
