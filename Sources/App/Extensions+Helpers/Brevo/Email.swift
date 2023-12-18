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
		// The address may be manually typed in by users, if a invalid value is given, this init function throws so that proper error could be dealt with.
		init(name: String, email: String) throws {
			guard email.range(of: emailRegex, options: .regularExpression) != nil else {
				throw MessageError.invalidEmailRecipient(recipient: email)
			}
			self.name = name
			self.email = email
		}
	}
	
	// The sender is defined as variable instead of constant, because compiler gives a warning says: Immutable property will not be decoded because it is declared with an initial value which cannot be overwritten.
	private var sender = try! Email.Account(name: "noreply", email: "noreply@mleak.top")
	let to: [Account]
	let subject: String
	let htmlContent: String
	
	init(to accounts: [Account], subject: String, message: MessageBody, client: Client) throws {
		// Recipients validation, each account should do validation by itself when initializing, and throws when regex is not match. So here we just check the array is not empty.
		guard !accounts.isEmpty else {
			let error = MessageError.invalidEmailRecipient(recipient: "Empty recipient")
			Self.alertAdmin(error: error, client: client)
			throw error
		}
		self.to = accounts
		
		// Subject can be anything but empty.
		guard !subject.isEmpty else {
			let error = MessageError.invalidEmailSubject
			Self.alertAdmin(error: error, client: client)
			throw error
		}
		self.subject = subject
		// Initializing a MessageBody struct throws if anything goes wrong, so if a MessageBody is successfully initialized, then we can set its string property directly without further checking.
		self.htmlContent = message.string
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
		// Emailing admin about crucial server side error, generating this mail is vital: it uses force try! to call throwing functions, so if these functions fail, server crash.
		let errorMessage = try! MessageBody(template: .sysError, placeHolders: [error.localizedDescription], client: client)
		let admin = try! Email.Account(name: "管理员", email: "admin@mleak.top")
		let mail = try! Self(to: [admin], subject: "\(serviceName)服务器错误", message: errorMessage, client: client)
		mail.send(client: client)
	}
}
