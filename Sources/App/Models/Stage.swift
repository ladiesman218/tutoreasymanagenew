//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/3/9.
//

import Vapor
import RegexBuilder

struct Stage: Codable {
	let directoryURL: URL
	let name: String
	let imageURL: URL?
	let description: String
	
	// Directory url for each chapter
	var chapterURLs: [URL] {
		let subURLs = directoryURL.subFoldersURLs
		// Only chapters' directory name match the regex will be returned, if a directory's name doesn't meet the critia, it won't be considered as a valid chapter and won't be shown. In case this filter returns an empty array, force unwrap in sorted method won't crash the app.
		return subURLs.filter { $0.lastPathComponent.contains(chapterPrefixRegex) }
			.sorted {
				// output of chapterPrefixRegex is the first int appear in chapter's name
				$0.lastPathComponent.firstMatch(of: chapterPrefixRegex)!.output.1 < $1.lastPathComponent.firstMatch(of: chapterPrefixRegex)!.output.1
			}
	}
	
	init(directoryURL: URL) {
		self.directoryURL = directoryURL
		self.name = directoryURL.lastPathComponent
		self.imageURL = getImageURLInDirectory(url: directoryURL)
		
		if let desc = try? String(contentsOf: directoryURL.appendingPathComponent("介绍.txt")) {
			self.description = desc
		} else if let desc = try? String(contentsOf: directoryURL.appendingPathComponent("\(name).txt")) {
			self.description = desc
		} else {
			self.description = ""
		}
	}
	
	// Without this, querying a stage will never get back its chapterURLs, since chapterURLs are defined as a caclulated property.
	struct PublicInfo: Content, CustomStringConvertible {
		let directoryURL: URL
		let name: String
		let imageURL: URL?
		let description: String
		let chapterURLs: [URL]
	}
	
	var publicList: PublicInfo {
		return .init(directoryURL: directoryURL, name: name, imageURL: imageURL, description: description, chapterURLs: [])
	}
	
	var publicInfo: PublicInfo {
		return .init(directoryURL: directoryURL, name: name, imageURL: imageURL, description: description, chapterURLs: chapterURLs)
	}
}
