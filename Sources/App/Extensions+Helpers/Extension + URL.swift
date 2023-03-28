//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/3/13.
//

import Foundation


extension URL {
	var isDirectory: Bool {
	   (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
	}
	
	var subFoldersURLs: [URL] {
		let subURLs = (try? FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])) ?? []
		
		return subURLs.filter { $0.isDirectory && $0.pathExtension.isEmpty }
	}
}
