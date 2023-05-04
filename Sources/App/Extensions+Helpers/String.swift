//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/5/4.
//

import Foundation

// This is a hack function copied from https://stackoverflow.com/questions/39234148/swift-string-hash-should-be-used-to-index-persistent-data
extension String {
	var persistantHash: Int {
		return self.utf8.reduce(5381) {
			($0 << 5) &+ $0 &+ Int($1)
		}
	}
}
