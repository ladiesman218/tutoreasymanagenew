//
//  File.swift
//
//
//  Created by Lei Gao on 2023/12/7.
//

import Vapor
import Queues

// For emails, sender contains a name(string) and an address(string), for SMS, sender is a string(phone number, may or may not contains +86. So wrap sender in an Account type, allow implementor to decider what type it should be.
protocol MessageAccount: Codable {
	associatedtype Account
	// For SMS, this function should add +86 if absent, so this function returns
	func validateAccount(client: Client) throws -> Account
}

protocol Message: MessageAccount, Codable {
	static var apiEndpoint: URI { get }
	// Static stored properties not supported in protocol extensions. So we can only set the value in each implementation even though all of them shares the same one.
	static var headers: HTTPHeaders { get }
	
	typealias Sender = Account
	// For email, recipient can be multiple(mandatory to be an array) so we will accommodate it. SMS will need to verify that only 1 item is in the array and send to the first one only.
	typealias Recipients = [Account]
	var sender: Sender { get }
	var recipients: Recipients { get }
	var body: String { get }
	init(recipients: Recipients, body: String, client: Client)
	func send(client: Client)
}

struct SMS: Codable {
	static let apiEndpoint = URI("https://api.brevo.com/v3/transactionalSMS/sms")
	static let headers = messageHTTPHeaders
	
	private let sender: String
	let recipient: String
	let content: String
	
	init?(recipient: String, template: String, placeHolders: [String], client: Client) {
		self.sender = "TutorEasy"
		// Recipient validation
		guard recipient.range(of: cnPhoneRegex, options: .regularExpression) != nil else {
			let error = MessageError.invalidSMSRecipient(recipient: recipient)
			Email.alertAdmin(error: error, client: client)
			return nil
		}
		
		let numberWithCountry = (recipient.hasPrefix("+86")) ? recipient : "+86" + recipient
		self.recipient = numberWithCountry
		
		// Message body validation. If convertToMessage() fails, it will send email to admin automatically
		let htmlRemoved = template.htmlRemoved
		guard let messageBody = htmlRemoved.convertToMessage(placeHolders: placeHolders, client: client) else {
			return nil
		}
		
		self.content = messageBody
	}
	
	func send(client: Client) {
		do {
			let data = try JSONEncoder().encode(self)
//			guard let string = String(data: data, encoding: .utf8) else {
//				throw Abort(.badRequest, reason: "Unable to convert data to string")
//			}
			
			// No need to wait for the response
			Task {
				// Per documentation, https://developers.brevo.com/reference/sendtransacsms, response's status will be 201 when sms sent, or 400 bad request, or 402 when credit is not enough.
				
				let response = try await client.post(Self.apiEndpoint, headers: messageHTTPHeaders, content: data)
				guard response.status.code < 300 && response.status.code > 200 else {
					throw MessageError.unableToSend(response: response)
				}
			}
		} catch {
			Email.alertAdmin(error: error, client: client)
		}
	}
}
extension Data: Content {}
