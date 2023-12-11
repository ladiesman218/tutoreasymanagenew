//
//  File.swift
//
//
//  Created by Lei Gao on 2023/12/7.
//

import Vapor
import Queues

struct SMS: Codable {
	static let apiEndpoint = URI("https://api.brevo.com/v3/transactionalSMS/sms")
	
	private let sender: String
	let recipient: String
	let content: String
	
	init?(recipient: User, template: MessageTemplates.Template, placeHolders: [String], client: Client) {
		self.sender = "TutorEasy"
		
		// Recipient validation
		guard let number = recipient.phone, number.range(of: cnPhoneRegex, options: .regularExpression) != nil else {
			let error = MessageError.invalidSMSRecipient(recipient: recipient)
			Email.alertAdmin(error: error, client: client)
			return nil
		}
		
		let numberWithCountry = (number.hasPrefix("+86")) ? number : "+86" + number
		self.recipient = numberWithCountry
		
		// Message body validation. If this fails, it will send email to admin automatically
		guard let messageString = MessageTemplates.generate(template: template, placeHolders: placeHolders, removeHTML: true, client: client) else {
			return nil
		}
		self.content = messageString
	}
	
	func send(client: Client) {
		do {
			let data = try JSONEncoder().encode(self)
			guard let string = String(data: data, encoding: .utf8) else {
				throw Abort(.badRequest, reason: "Unable to convert sms data to string: \(self)")
			}
			
			// No need to wait for the response
			Task {
				// According to documentation, https://developers.brevo.com/reference/sendtransacsms, response's status will be 201 when sms sent, or 400 bad request, or 402 when credit is not enough.
				let response = try await client.post(Self.apiEndpoint, headers: messageHTTPHeaders, content: string)
				guard response.status.code < 300 && response.status.code >= 200 else {
					Email.alertAdmin(error: MessageError.unableToSend(response: response), client: client)
					return
				}
			}
		} catch {
			Email.alertAdmin(error: error, client: client)
		}
	}
}
