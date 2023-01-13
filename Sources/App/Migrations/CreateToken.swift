import Fluent


struct CreateToken: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(Token.schema)
			.id()
			.field(Token.FieldKeys.value, .string, .required)
			.field(Token.FieldKeys.userID, .uuid, .required, .references("users", "id", onDelete: .cascade))
			.create()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(Token.schema).delete()
	}
}


