import Fluent
import FluentPostgresDriver

struct CreateLanguage: AsyncMigration {
	func prepare(on database: Database) async throws {
	#warning("Add constraint, if published is true, iapIdentifier couldn't be empty")
		try await database.schema(Language.schema).id()
			.field(Language.FieldKeys.name, .string, .required).unique(on: Language.FieldKeys.name)
			.field(Language.FieldKeys.description, .string)
			.field(Language.FieldKeys.published, .bool, .required)
			.field(Language.FieldKeys.price, .double, .required)
			.field(Language.FieldKeys.iapIdentifier1, .string, .required).unique(on: Language.FieldKeys.iapIdentifier1)
			.create()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(Language.schema).delete()
	}
}

