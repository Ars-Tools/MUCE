//
//  Mach.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
@preconcurrency import Darwin
public enum Mach {
	final class Port {
		let handle: mach_port_t
		init() {
			var port: mach_port_name_t = 0
			mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &port)
			handle = 0
		}
		deinit {
			mach_port_deallocate(mach_task_self_, handle)
		}
	}
}
