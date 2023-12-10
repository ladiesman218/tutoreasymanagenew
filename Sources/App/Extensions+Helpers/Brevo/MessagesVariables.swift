//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/12/11.
//

import Foundation
import Vapor

var brevoAPI: String {
	get{ return Environment.get("BREVOAPI")! }
}
let messageHTTPHeaders: HTTPHeaders = {
	var headers = HTTPHeaders()
	headers.replaceOrAdd(name: .accept, value: "application/json")
	headers.replaceOrAdd(name: .contentType, value: "application/json")
	headers.replaceOrAdd(name: "api-key", value: brevoAPI)
	return headers
}()
