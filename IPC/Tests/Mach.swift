//
//  Mach.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
import Testing
@preconcurrency import MachO
@preconcurrency import Foundation
@testable import IPC
protocol MachPort {
	
}
final class Dispose {
	let handle: mach_port_t
	init(handle: mach_port_t) {
		self.handle = handle
	}
	deinit {
		print(handle, mach_port_deallocate(mach_task_self_, handle), KERN_SUCCESS)
	}
}
extension Dispose {
	convenience init(recv: Int) {
		var port = 0 as mach_port_t
		guard mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &port) == KERN_SUCCESS else {
			fatalError()
		}
		self.init(handle: port)
	}
}

@Suite
struct MachTests {
	let domain = "tools.ars.ipc.test.example"
	func recv(count: Int) throws {
		let x = Dispose(recv: 0)
		var recv: mach_port_t = 0
		guard mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &recv) == KERN_SUCCESS else {
			Issue.record("cannot be allocated")
			return
		}
		defer {
			mach_port_deallocate(mach_task_self_, recv)
		}
		guard mach_port_insert_right(mach_task_self_, recv, recv, .init(MACH_MSG_TYPE_MAKE_SEND)) == KERN_SUCCESS else {
			Issue.record("cannot be authorised")
			return
		}
		guard bootstrap_register(bootstrap_port, domain, recv) == KERN_SUCCESS else {
			Issue.record("cannot be registered")
			return
		}
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<mach_msg_header_t>.stride + count + MemoryLayout<mach_msg_trailer_t>.stride,
									  alignment: MemoryLayout<mach_msg_header_t>.alignment) {
			switch mach_msg(
				$0.bindMemory(to: mach_msg_header_t.self).baseAddress,
				MACH_RCV_MSG,
				0,
				.init($0.count),
				recv,
				.init(MACH_MSG_TIMEOUT_NONE),
				.init(MACH_PORT_NULL)
			) {
			case KERN_SUCCESS:
				break
			case let status:
				Issue.record("cannot send \(String(cString: mach_error_string(status)))")
			}
		}
	}
	func send(count: Int) throws {
		var send: mach_port_t = 0
		guard bootstrap_look_up(bootstrap_port, domain, &send) == KERN_SUCCESS else {
			Issue.record("cannot be found")
			return
		}
		withUnsafeTemporaryAllocation(byteCount: MemoryLayout<mach_msg_header_t>.stride + count,
									  alignment: MemoryLayout<mach_msg_header_t>.alignment) {
			let header = $0.bindMemory(to: mach_msg_header_t.self)
			header[0].msgh_bits = .init(MACH_MSG_TYPE_COPY_SEND)
			header[0].msgh_remote_port = send
			header[0].msgh_local_port = .init(MACH_PORT_NULL)
			switch mach_msg(
				header.baseAddress,
				MACH_SEND_MSG,
				.init($0.count),
				0,
				.init(MACH_PORT_NULL),
				.init(MACH_MSG_TIMEOUT_NONE),
				.init(MACH_PORT_NULL)) {
			case KERN_SUCCESS:
				break
			case let status:
				Issue.record("cannot send \(String(cString: mach_error_string(status)))")
			}
		}
	}
	@Test
	func example() async throws {
		async let recv: () = withCheckedThrowingContinuation { future in
			Thread {
				do {
					try self.recv(count: 0)
					future.resume()
				} catch {
					future.resume(throwing: error)
				}
			}.start()
		} as Void
		try await Task.sleep(for: .seconds(1))
		async let send: () = withCheckedThrowingContinuation { future in
			Thread {
				do {
					try self.send(count: 0)
					future.resume()
				} catch {
					future.resume(throwing: error)
				}
			}.start()
		} as Void
		((), ()) = try await (recv, send)
	}
}
