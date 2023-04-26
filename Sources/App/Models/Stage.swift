//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/3/9.
//

import Vapor

struct Stage: Codable {
	let directoryURL: URL
	let name: String
	let imageURL: URL?
	let description: String
	
	var chapters: [Chapter] {
		let subURLs = directoryURL.subFoldersURLs
		let chapters = subURLs.map { Chapter(directoryURL: $0) }
		return chapters.sorted {
			return $0.name < $1.name
		}
	}
	
	init(directoryURL: URL) {
		self.directoryURL = directoryURL
		self.name = directoryURL.lastPathComponent
		self.imageURL = getImageURLInDirectory(url: directoryURL)
		
		if let desc = try? String(contentsOf: directoryURL.appendingPathComponent("介绍.txt")) {
			self.description = desc
		} else {
			self.description = ""
		}
	}
	
	// Without this, querying a stage will never get back its chapters, since chapters are defined as a caclulated property.
	struct PublicInfo: Content, Hashable {
		let directoryURL: URL
		let name: String
		let imageURL: URL?
		let description: String
		let chapters: [Chapter]
	}
	
	var publicList: PublicInfo {
		return .init(directoryURL: directoryURL, name: name, imageURL: imageURL, description: description, chapters: [])
	}
	
	var publicInfo: PublicInfo {
		return .init(directoryURL: directoryURL, name: name, imageURL: imageURL, description: description, chapters: chapters)
	}
}
