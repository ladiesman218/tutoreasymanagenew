import Fluent
import FluentPostgresDriver

struct CreateUser: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(User.schema).id()
			.field(User.FieldKeys.username, .string, .required).unique(on: User.FieldKeys.username)
			.field(User.FieldKeys.firstName, .string)
			.field(User.FieldKeys.lastName, .string)
			.field(User.FieldKeys.email, .string, .required).unique(on: User.FieldKeys.email)
			.field(User.FieldKeys.password, .string, .required)
			.field(User.FieldKeys.profilePic, .string)
			.field(User.FieldKeys.registerTime, .datetime)
			.field(User.FieldKeys.lastLoginTime, .datetime)
			.create()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(User.schema).delete()
	}
}

