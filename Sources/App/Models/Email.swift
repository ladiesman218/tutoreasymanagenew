//
//  File.swift
//
//
//  Created by Lei Gao on 2023/11/16.
//

import Vapor
import Foundation
import Queues

// Tencent has free business email service which limits space using of 1GB(https://work.weixin.qq.com/wework_admin/frame#/business/mall/productIntro/exmail?mngEnter=1&from=nmall_scenes_exmail_yysy1_button_web_free), we've set up the domain mleak.top to use it. In order to send email in this app with those email addresses, we need to create an business app inside tencent's business wechat management end(also done). But to test sending emails, a ICP License must be retrived first, for that we need a tencent server with at least 3 months of expiring time

struct Email {
	
	let sender: Account
	let recipients: [Account]
	let subject: String
	let emailMessage: Body
	
	func validate() throws {
		guard !sender.name.isEmpty && sender.email.range(of: emailRegex, options: .regularExpression) != nil else {
			throw EmailError.invalidSender(sender: sender)
		}
		
		if let invalidRecipient = recipients.filter({ $0.name.isEmpty || $0.email.range(of: emailRegex, options: .regularExpression) == nil}).first {
			throw EmailError.invalidRecipient(recipient: invalidRecipient)
		}
		guard !subject.isEmpty else {
			throw EmailError.invalidSubject
		}
	}
	
	func send(client: Client) {
		do {
			try validate()
			// CustomStringConvertible protocol gives a description variable, but that makes working with multi-line strings harder. So here we convert self to data, then convert that data back to string again...
			let data = try JSONEncoder().encode(self)
			guard let string = String(data: data, encoding: .utf8) else {
				throw Abort(.badRequest, reason: "Unable to convert data to string")
			}
			
			// No need to wait for the response
			Task {
				// Per documentation, https://developers.brevo.com/reference/sendtransacemail, response's status will be 201 when email sent, or 202 when email is scheduled, or 400 when failing
				var headers = HTTPHeaders()
				headers.replaceOrAdd(name: .accept, value: "application/json")
				headers.replaceOrAdd(name: .contentType, value: "application/json")
				headers.replaceOrAdd(name: "api-key", value: Self.brevoAPI)
				
				let response = try await client.post(Self.apiEndpoint, headers: headers, content: string)
				guard response.status.code < 300 && response.status.code > 200 else {
					throw EmailError.unableToSend(response: response)
				}
			}
		} catch {
			Self.alertAdmin(error: error, client: client)
		}
	}
}

// Define static variables and sub-type
extension Email {
	static let apiEndpoint = URI(string: "https://api.brevo.com/v3/smtp/email")
	static var brevoAPI:String {
		get{ return Environment.get("BREVOAPI")! }
	}
	
	struct Account: Codable {
		let name: String
		let email: String
		static let admin = Self(name: "admin", email: "admin@mleak.top")
		static let noreply = Self(name: "noreply", email: "noreply@mleak.top")
	}
	
	// HTML content for an email's body. This uses the generate() function to sequentially replace every placeHolder value in the given html string.
	struct Body: Codable {
		enum CodingKeys: String, CodingKey {
			case htmlContent = "htmlContent"
		}
		
		let htmlContent: String
		static let placeHolder = "${placeHolder}"
		static let verificationCodeTemplate = """
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
		
		// Marked as private so an instance can only be created by the generate() function.
		private init(htmlContent: String) {
			self.htmlContent = htmlContent
		}
		// Pass in client, so when this function throws, admin will get an email alert.
		static func generate(placeHolders: [String], template: String, client: Client) throws -> Self {
			guard !template.isEmpty else {
				let error =  EmailError.messageBodyError(template: template, placeHolders: placeHolders)
				Email.alertAdmin(error: error, client: client)
				throw error
			}
			// If no separator is found in html, the entire string will be split to an array contains 1 item.
			let array = template.split(separator: Self.placeHolder)
			guard placeHolders.count + 1 == array.count else {
				let error =  EmailError.messageBodyError(template: template, placeHolders: placeHolders)
				Email.alertAdmin(error: error, client: client)
				Email.alertAdmin(error: error, client: client)
				throw error
			}
			
			var message = String(array.first!)
			var i = 1
			// If placeHolders is empty, the forEach loop won't execute
			placeHolders.forEach {
				message += String($0) + array[i]
				i += 1
			}
			
			return .init(htmlContent: message)
		}
	}
	
	static func alertAdmin(error: Error, client: Client) {
		let message: Body
		// Emailing admin about crucial server side error, generating this error message is vital: it uses `try!` so if anything goes wrong, server app crash.
		if let error = error as? DebuggableError {
			message = try! .generate(placeHolders: [error.reason], template: Body.sysErrorTemplate, client: client)
		} else {
			message = try! .generate(placeHolders: [error.localizedDescription], template: Body.sysErrorTemplate, client: client)
		}
		
		let mail = Self(sender: .admin, recipients: [.admin], subject: "Tutor Easy SYS Error", emailMessage: message)
		mail.send(client: client)
	}
}

extension Email: Codable {
	enum CodingKeys: String, CodingKey {
		case sender = "sender"
		case recipients = "to"
		case htmlContent = "htmlContent"
		case subject = "subject"
	}
	
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		subject = try values.decode(String.self, forKey: .subject)
		sender = try values.decode(Account.self, forKey: .sender)
		recipients = try values.decode([Account].self, forKey: .recipients)
		
		let bodyContainer = try values.nestedContainer(keyedBy: Body.CodingKeys.self, forKey: .htmlContent)
		emailMessage = try bodyContainer.decode(Body.self, forKey: .htmlContent)
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(subject, forKey: .subject)
		try container.encode(sender, forKey: .sender)
		try container.encode(recipients, forKey: .recipients)
		// Avoid encode to nested object by getting the nested value directly.
		try container.encode(emailMessage.htmlContent, forKey: .htmlContent)
	}
}
