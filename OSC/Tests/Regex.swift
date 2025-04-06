//
//  Regex.swift
//  MUCE
//
//  Created by Kota on 4/6/R7.
//
import Testing
import func Darwin.fnmatch
import let Darwin.FNM_PATHNAME
import let Darwin.FNM_NOMATCH
@testable import OSC
@Suite
struct RegexTests {
	@Test(arguments: [
		("/test/?", "/te"),
		("/test/?", "/test"),
		("/test/?", "/test/1"),
		("/test/?", "/test/1/2"),
		("/test/?", "/test/123"),
		("/test/*", "/te"),
		("/test/*", "/test"),
		("/test/*", "/test/1"),
		("/test/*", "/test/1/2"),
		("/test/*", "/test/123"),
	])
	func glob(pattern: String, query: String) {
		let filter = try?Regex(osc: pattern)
		switch fnmatch(pattern, query, FNM_PATHNAME) {
		case 0:
			guard let filter else {
				Issue.record("transation has failed")
				return
			}
			guard case.some = query.wholeMatch(of: filter) else {
				Issue.record("pattern should be match")
				return
			}
		case FNM_NOMATCH:
			guard let filter else {
				Issue.record("transation has failed")
				return
			}
			guard case.none = query.wholeMatch(of: filter) else {
				Issue.record("pattern should not be match")
				return
			}
		default:
			guard case.none = filter else {
				Issue.record("translation should be failed")
				return
			}
		}
	}
	@Test(arguments: [
		("/test/**", "/test/a", true),
		("/test/**", "/test/ab", true),
		("/test/**", "/test/a/b", true),
		("/test/**", "/test/a/b/c", true),
		("/second/[1-2]", "/second/1", true),
		("/second/[1-2]", "/second/2", true),
		("/second/[1-2]", "/second/3", false),
		("/second/[1-2]", "/second/test", false),
		("/second/[3,5]", "/second/3", true),
		("/second/[3,5]", "/second/4", false),
		("/second/[3,5]", "/second/5", true),
		("/second/[3,5]", "/second/6", false),
		("/second/[!3]", "/second/4", true),
		("/second/[!3]", "/second/3", false),
		("c{at,ub}s", "cats", true),
		("c?s", "cats", false),
		("c??s", "cat", false),
		("ca[a-z]", "cat", true),
		("ca[!t]", "cat", false),
	])
	func wildcard(pattern: String, query: String, expect: Bool) throws {
		let result = switch try Regex(osc: pattern).wholeMatch(in: query) {
		case.some:
			true
		case.none:
			false
		}
		#expect(result == expect)
	}
}
