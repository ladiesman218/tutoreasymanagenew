//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/10/5.
//

import Vapor

extension DebuggableError {
	public var localizedDescription: String {
		self.reason
	}
}

extension Array where Element == any DebuggableError {
    var reasons: String {
        let res = self.compactMap { $0.reason }.joined(separator: "\n")
        return res
    }
    
    var abort: Abort {
        return Abort(.badRequest, reason: reasons)
    }
}
