//
//  File.swift
//
//
//  Created by Lei Gao on 2023/12/8.
//

import Foundation
import Vapor

struct MessageTemplates {
	static let verificationCode = """
 <html><head></head>
 <body>
 <font size="3">
 <p>您的师轻松验证码为:</p>
 <font size="6">
 <p>\(placeHolder)</p>
 </font>
 <p>该验证码有效期为5分钟，请妥善保管不要告知他人</p>
 <p>如非本人操作，请忽略此邮件</p>
 </font>
 </body></html>
 """

	static let sysErrorTemplate = """
 <html><head></head>
 <body>
<p>师轻松服务器错误：</p>
<p>\(placeHolder)</p>
 </body></html>
"""
	
	static func generate(template: String, placeHolders: [String], client: Client) throws -> String {
		guard !template.isEmpty else {
			let error =  MessageError.messageBodyError(template: template, placeHolders: placeHolders)
			Email.alertAdmin(error: error, client: client)
			throw error
		}
		// Make sure number of placeholders are identical in both array and template
		guard placeHolders.count == template.countOccurrences(of: placeHolder) else {
			let error =  MessageError.messageBodyError(template: template, placeHolders: placeHolders)
			Email.alertAdmin(error: error, client: client)
			throw error
		}
		
		var messageString = template
		placeHolders.forEach {
			messageString = messageString.replacing(placeHolder, with: $0, maxReplacements: 1)
		}
		return messageString
	}
}
let a = MessageTemplates.generate
