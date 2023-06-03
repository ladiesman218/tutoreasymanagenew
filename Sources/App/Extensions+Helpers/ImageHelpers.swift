//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/10/5.
//

import Foundation

enum ImageName: String, CaseIterable {
    case image
    case banner
}

enum ImageExtension: String, CaseIterable {
    case png
    case jpg
    case jpeg
}

func getImageURLInDirectory(url: URL) -> URL? {
	
	let lastPath = url.lastPathComponent
	let withoutTrail = lastPath.replacing(trialRegex, with: "")
	let withoutPrefix = lastPath.replacing(chapterPrefixRegex, with: "")
	let pureName = withoutPrefix.replacing(trialRegex, with: "")
	let allCases = [lastPath, withoutPrefix, withoutTrail, pureName] + ImageName.allCases.map { $0.rawValue }
	
	for name in allCases {
        for imageExtension in ImageExtension.allCases {
            let imageURL = url.appendingPathComponent(name).appendingPathExtension(imageExtension.rawValue)
            // URL may contain percentEncoding, for example we may use Chinese characters in directory names, then use url.appendingPathComponent(name) to generate urls, that case the 'name' part is automatically url encoded, thus will become something like this: '../Course/%E5%88%9B%E6%96%B0%E5%90%A7'. Using that url string as a path to find files is always gonna fail, using path can automatically remove the url encoding, so it gets back to '../Course/课程名称'
            if FileManager.default.fileExists(atPath: imageURL.path) {
				return imageURL.standardizedFileURL
            }
        }
    }
	return nil
}
