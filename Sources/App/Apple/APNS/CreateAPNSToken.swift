//
//  File.swift
//  
//
//  Created by Lei Gao on 2024/1/18.
//

import Fluent
import FluentKit

struct CreateAPNSToken: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(APNSDevice.schema).id()
			.field("token", .data, .required)
			.field("user_id", .uuid, .references(User.schema, .init(stringLiteral: "id"), onDelete: .cascade))
			.field("device_id", .uuid, .required).unique(on: "device_id")
			.create()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(APNSDevice.schema).delete()
	}
}
