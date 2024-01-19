//
//  File.swift
//
//
//  Created by Lei Gao on 2024/1/18.
//

import Vapor
import Fluent

final class APNSDevice: Model, Content {
	static let schema = "apns_devices"
	
	@ID var id: UUID?
	@Field(key: "token") var token: Data
	@OptionalParent(key: "user_id") var user: User?
	@Field(key: "device_id") var deviceID: UUID
	
	init() {}
	init(id: UUID? = nil, token: Data, userID: User.IDValue?, deviceID: UUID) {
		self.id = id
		self.token = token
		self.$user.id = userID
		self.deviceID = deviceID
	}
	
	struct DTO: Content {
		let token: Data
		let userID: UUID?
		let deviceID: UUID
	}
	
	func tokenString() -> String {
		return token.map { String(format: "%02.2hhx", $0) }.joined()
	}
}
