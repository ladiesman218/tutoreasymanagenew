//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/3/26.
//

import Foundation

extension Array where Element == String {
	func generatePath() -> String {
		let path = self.joined(separator: "/")
		// If first element does indeed is /, or has prefix of /, then join all elements
		return (path.hasPrefix("/")) ? path : "/" + path
	}
	
	// Generate a file url from an array of strings
	func generateURL() throws -> URL {
		// Make sure the array is not empty
		guard !self.isEmpty else { throw GeneralInputError.invalidURL }
		
		// Make sure the url is generated from root directory instead of current working directory
		var url = URL(fileURLWithPath: "/")
		
		guard self.count > 1 else { return url }
		
		for index in 0 ... self.count - 1 {
			url = url.appendingPathComponent(self[index])
		}
		return url.standardizedFileURL
	}
}
