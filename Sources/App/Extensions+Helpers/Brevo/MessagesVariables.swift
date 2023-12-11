//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/12/11.
//

import Foundation
import Vapor

let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9]+\\.?[A-Za-z0-9]+\\.[A-Za-z]{2,64}$"
let cnPhoneRegex = "^\\+?(86)?[ -]?1[3-9][0-9][ -]?[0-9]{4}[ -]?[0-9]{4}$"
let adminEmail = "tutoreasy@mleak.top"

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
