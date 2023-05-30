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
	
	var chapters: [Chapter] {
		let subURLs = directoryURL.subFoldersURLs
		let chapters = subURLs.map { Chapter(directoryURL: $0) }
		
		let regex = Regex {
			ZeroOrMore(.word, .reluctant)
			TryCapture {
				OneOrMore(.digit)
			} transform: {
				Int($0)
			}
			ZeroOrMore(.word)
			OneOrMore {
				ChoiceOf {
					":"
					"："
				}
			}
		}
		
		return chapters.filter {
			// Only chapter names match the regex will be returned, if a directory's name doesn't meet the critia, it won't be considered as a valid chapter and won't be shown. In case this filter returns an empty array, force unwrap in sorted method won't crash the app.
			$0.name.contains(regex)
		}.sorted {
			print($0.name.firstMatch(of: regex)!.output.0, $0.name.firstMatch(of: regex)!.output.1)
			return $0.name.firstMatch(of: regex)!.output.1 < $1.name.firstMatch(of: regex)!.output.1
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
	struct PublicInfo: Content {
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
