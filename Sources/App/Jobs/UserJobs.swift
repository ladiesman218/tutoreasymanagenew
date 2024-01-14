//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/11/22.
//

import Vapor
import Queues
import Fluent

struct UserExecution: Codable {
	
	enum Execution: String, Codable {
		case deleteCode, deleteUser
	}
	
	let execution: Execution
	let userID: User.IDValue
	var code: VerificationCode?
}

struct UserJobs: AsyncJob {
	typealias Payload = UserExecution
	
	func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
		guard let user = try await User.find(payload.userID, on: context.application.db) else {
			throw AuthenticationError.userNotFound
		}
		switch payload.execution {
			case .deleteCode:
				// Payload contains a user's verification code, make sure the code(both code value itself and the time of generation) matches the one stored in db, if not, bail out
				guard user.verificationCode == payload.code else { return }
				user.verificationCode = nil
				try await user.save(on: context.application.db)
			case .deleteUser:
				guard !user.verified else { return }
				try await user.delete(on: context.application.db)
		}
	}
	
	func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
		context.logger.critical(
			"Execute user job failed",
			metadata: [
				"payload": "\(payload)",
				"error description": "\(error.localizedDescription)"
			]
		)
		// If you don't want to handle errors you can simply return. You can also omit this function entirely.
	}
}
