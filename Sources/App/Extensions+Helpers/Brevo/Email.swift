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

struct Email: Codable {

	static let apiEndpoint = URI(string: "https://api.brevo.com/v3/smtp/email")

	struct Account: Codable {
		let name: String
		let email: String
	}
	
	// Sender can only be the given options
	enum Sender {
		case admin
		case noreply
		
		var account: Account {
			switch self {
				case .admin:
					return Account(name: "admin", email: "admin@mleak.top")
				case .noreply:
					return Account(name: "noreply", email: "noreply@mleak.top")
			}
		}
	}
	
	let sender: Account
	let to: [Account]
	let subject: String
	let htmlContent: String
	
	init?(sender: Sender, to users: [User], subject: String, template: MessageTemplates.Template, placeHolders: [String], client: Client) {
		let senderAccount = sender.account
		// Sender validation
		guard !senderAccount.name.isEmpty && senderAccount.email.range(of: emailRegex, options: .regularExpression) != nil else {
			let error = MessageError.invalidEmailSender(sender: senderAccount)
			Self.alertAdmin(error: error, client: client)
			return nil
		}
		self.sender = senderAccount
		
		// Recipients validation, db has constraints to check all stored email string match the regex, here we only need to check if a user's email is nil.
		let invalidRecipients = users.filter({ $0.email == nil })
		guard invalidRecipients.isEmpty else {
			invalidRecipients.forEach {
				Self.alertAdmin(error: MessageError.invalidEmailRecipient(recipient: $0), client: client)
			}
			return nil
		}
		
		self.to = users.map { Account(name: $0.username, email: $0.email!) }
		
		// Subject can be anything but empty
		guard !subject.isEmpty else {
			let error = MessageError.invalidEmailSubject
			Self.alertAdmin(error: error, client: client)
			return nil
		}
		self.subject = subject
		
		// Generate message body, if calling this function fails, an alert email will be sent from passed in client to admin automatically.
		guard let messageString = MessageTemplates.generate(template: template, placeHolders: placeHolders, client: client) else { return nil }
		self.htmlContent = messageString
	}
	
	func send(client: Client) {
		do {
			// Brevo requires String type for content parameter. CustomStringConvertible protocol gives a description variable, but that makes working with multi-line strings harder. So here we convert self to json data, then convert that data back to string again...
			let data = try JSONEncoder().encode(self)
			guard let string = String(data: data, encoding: .utf8) else {
				throw Abort(.badRequest, reason: "Unable to convert email data to string: \(self)")
			}
			
			// No need to wait for the response
			Task {
				// According to documentation, https://developers.brevo.com/reference/sendtransacemail, response's status will be 201 when email sent, or 202 when email is scheduled, or 400 when failed
				let response = try await client.post(Self.apiEndpoint, headers: messageHTTPHeaders, content: string)
				guard response.status.code < 300 && response.status.code >= 200 else {
					Self.alertAdmin(error: MessageError.unableToSend(response: response), client: client)
					return
				}
			}
		} catch {
			Self.alertAdmin(error: error, client: client)
		}
	}
	
	static func alertAdmin(error: Error, client: Client) {
		// Emailing admin about crucial server side error, generating this mail is vital: it uses force unwrap for optional return values, so if anything goes wrong, server app crash.
		let errorDescription: String
		if let error = error as? DebuggableError {
			errorDescription = MessageTemplates.generate(template: .sysError, placeHolders: [error.reason], client: client)!
		} else {
			errorDescription = MessageTemplates.generate(template: .sysError, placeHolders: [error.localizedDescription], client: client)!
		}
		let user = User(primaryContact: .email, email: "admin@mleak.top", username: "Admin", password: "12345")
		let mail = Self(sender: .noreply, to: [user], subject: "Backend error for tutor easy", template: .sysError, placeHolders: [errorDescription], client: client)!
		mail.send(client: client)
	}
}
