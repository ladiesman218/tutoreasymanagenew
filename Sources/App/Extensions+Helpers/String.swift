//
//  File.swift
//
//
//  Created by Lei Gao on 2023/5/4.
//

import Foundation
import Vapor

// This is a hack function copied from https://stackoverflow.com/questions/39234148/swift-string-hash-should-be-used-to-index-persistent-data
extension String {
	var persistantHash: Int {
		return self.utf8.reduce(5381) {
			($0 << 5) &+ $0 &+ Int($1)
		}
	}
	
	// For parsing chapter names
	var withoutTrail: String {
		return self.replacing(trialRegex, with: "")
	}
	var withoutNum: String {
		return self.replacing(chapterPrefixRegex, with: "")
	}
}

extension String {
	func countOccurrences(of substring: String) -> Int {
		var count = 0
		var searchStartIndex = startIndex
		
		while let range = self[searchStartIndex...].range(of: substring) {
			count += 1
			searchStartIndex = range.upperBound
		}
		
		return count
	}
	
	// If a string contains html tags, remove those tags
	var htmlRemoved: Self {
		// 定义匹配HTML标记的正则表达式
		let regex = try! NSRegularExpression(pattern: "<[^>]+>|\\{[^}]+\\}", options: .caseInsensitive)
		
		// 使用正则表达式替换匹配到的标记
		let range = NSRange(location: 0, length: self.utf16.count)
		let htmlAndCSSFree = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
		
		return htmlAndCSSFree
	}
}
