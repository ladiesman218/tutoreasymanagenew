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
	
	private var sender: String = serviceName
	let recipient: String
	let content: String
	
	// The recipient may be manually typed in by users, if a invalid value is given, this init function throws so that proper error could be dealt with.
	init(recipient: String, message: MessageBody, client: Client) throws {
		// Recipient validation
		guard recipient.range(of: cnPhoneRegex, options: .regularExpression) != nil else {
			throw MessageError.invalidSMSRecipient(recipient: recipient)
		}
		
		let numberWithCountry = (recipient.hasPrefix("+86")) ? recipient : "+86" + recipient
		self.recipient = numberWithCountry
		
		self.content = message.string
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
