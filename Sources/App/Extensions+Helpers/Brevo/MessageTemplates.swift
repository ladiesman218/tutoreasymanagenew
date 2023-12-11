//
//  File.swift
//
//
//  Created by Lei Gao on 2023/12/8.
//

import Foundation
import Vapor

struct MessageTemplates {
	
	static let placeHolder = "${placeHolder}"
	
	enum Template {
		case verificationCode, sysError
		// Since raw value for enum case must be a literal, we can't do string interpolation in raw values.
		var text: String {
			switch self {
				case .verificationCode:
					return  """
 <html><head></head>
 <body>
 <font size="3">
 <p>您的师轻松验证码为:</p>
 <font size="6">
 <p>\(MessageTemplates.placeHolder)</p>
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
 <p>\(MessageTemplates.placeHolder)</p>
 </body></html>
 """
			}
		}
	}
	
	static func generate(template: Template, placeHolders: [String], removeHTML: Bool = false, client: Client) -> String? {
		var messageString = template.text
		messageString = removeHTML ? messageString.htmlRemoved : messageString
		
		guard !messageString.isEmpty else {
			let error = MessageError.messageBodyError(template: messageString, placeHolders: placeHolders)
			Email.alertAdmin(error: error, client: client)
			return nil
		}
		// Make sure number of placeholders are identical in both array and template
		guard placeHolders.count == messageString.countOccurrences(of: Self.placeHolder) else {
			let error =  MessageError.messageBodyError(template: messageString, placeHolders: placeHolders)
			Email.alertAdmin(error: error, client: client)
			return nil
		}
		
		placeHolders.forEach {
			messageString = messageString.replacing(placeHolder, with: $0, maxReplacements: 1)
		}
		return messageString
	}
}
