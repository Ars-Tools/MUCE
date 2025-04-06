//
//  Context.swift
//  MUCE
//
//  Created by Kota on 3/31/R7.
//
public typealias Context = Dictionary<Character, Argument.Type>
extension Context {
	public static let `default`: Self = [
		"i": Int32.self,
		"f": Float32.self,
		"s": String.self,
		"b": Blob.self,
		
		"h": Int64.self,
		"d": Float64.self,
		"S": Symbol.self,
		"c": Character.self,
		
		"r": Color.self,
		"m": MIDIMessage.self,
		"t": TimeTag.self,
		
		"T": Bool.self,
		"F": Bool.self,
		"I": Impulse.self,
		"N": Nil.self,
		
		"[": Array<Argument>.self,
		"]": Array<Argument>.self,
		
	]
}
