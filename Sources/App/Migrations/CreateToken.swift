import Fluent


struct CreateToken: Migration {
	
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		database.schema(Token.schema)
			.id()
			.field(Token.FieldKeys.value, .string, .required)
			.field(Token.FieldKeys.userID, .uuid, .required, .references("users", "id", onDelete: .cascade))
			.create()
	}
	
	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.schema(Token.schema).delete()
	}
}


