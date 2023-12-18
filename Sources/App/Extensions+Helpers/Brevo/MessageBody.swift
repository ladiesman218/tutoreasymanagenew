//
//  File.swift
//
//
//  Created by Lei Gao on 2023/12/8.
//

import Foundation
import Vapor

struct MessageBody {
	
	static let placeHolder = "${placeHolder}"
	
	enum Template {
		case verificationCode, sysError
		// Since raw value for enum case must be a literal, we can't do string interpolation in raw values, hence the computed property.
		var text: String {
			switch self {
				case .verificationCode:
					return  """
 <html><head></head>
 <body>
 <font size="3">
 <p>您的师轻松验证码为:</p>
 <font size="6">
 <p>\(MessageBody.placeHolder)</p>
 </font>
 <p>该验证码有效期为5分钟，请妥善保管不要告知他人</p>
 <p>如非本人操作，请忽略此邮件</p>
 </font>
 </body></html>
 """
				case .sysError:
					return """
 <html><head></head>
 <body>
 <p>师轻松服务器错误：</p>
 <p>\(MessageBody.placeHolder)</p>
 </body></html>
 """
			}
		}
	}
	
	let string: String
	
	init(template: Template, placeHolders: [String], removeHTML: Bool = false, client: Client) throws {
		var messageString = template.text
		messageString = removeHTML ? messageString.htmlRemoved : messageString
		
		guard !messageString.isEmpty else {
			let error = MessageError.messageBodyError(template: messageString, placeHolders: placeHolders)
			Email.alertAdmin(error: error, client: client)
			throw error
		}
		// Make sure number of placeholders are identical in both array and template
		guard placeHolders.count == messageString.countOccurrences(of: Self.placeHolder) else {
			let error =  MessageError.messageBodyError(template: messageString, placeHolders: placeHolders)
			Email.alertAdmin(error: error, client: client)
			throw error
		}
		
		placeHolders.forEach {
			messageString = messageString.replacing(Self.placeHolder, with: $0, maxReplacements: 1)
		}
		self.string = messageString
	}
}
