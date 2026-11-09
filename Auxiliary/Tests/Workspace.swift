//
//  Workspace.swift
//  MUCE
//
//  Created by Kota on 11/9/26.
//
import Testing
import typealias Accelerate.vDSP
@testable import Auxiliary
@Suite
struct WorkspaceTestCases {
    @Test
    func raw() {
        let c = Workspace.alloc(byteCount: 256, alignment: MemoryLayout<Int>.alignment) {
            let a = $0.consume(of: Int.self, capacity: 4)
            let b = $0.consume(of: Int.self, capacity: 4)
            _ = a.initialize(from: 0...)
            _ = b.initialize(from: 0...)
            return zip(a, b).map(+)
        }
        #expect(c == (0..<4).map { $0 &* 2 })
    }
    @Test
    func typed() {
        let c = Workspace.alloc(of: Float64.self, capacity: 28) {
            let a = $0.consume(prefix: 4)
            let b = $0.consume(prefix: 4)
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &a[0..<a.count])
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &b[0..<b.count])
            return vDSP.add(a, b)
        }
        #expect(c == (0..<4).map { Float64($0) * 2 })
    }
}
