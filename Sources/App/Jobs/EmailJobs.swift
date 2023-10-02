//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/9/14.
//

import Vapor
import Foundation
import Queues

struct Email: Codable {
	let to: String
	let message: String
}

struct EmailJob: AsyncJob {
	typealias Payload = Email
	
	func dequeue(_ context: QueueContext, _ payload: Email) async throws {
		print("email sent")
		// This is where you would send the email
	}
	
	func error(_ context: QueueContext, _ error: Error, _ payload: Email) async throws {
		print("send email error")
		// If you don't want to handle errors you can simply return. You can also omit this function entirely.
	}
}
