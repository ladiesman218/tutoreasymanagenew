import Fluent
import FluentPostgresDriver

struct CreateLanguage: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema(Language.schema).id()
			.field(Language.FieldKeys.name, .string, .required).unique(on: Language.FieldKeys.name)
			.field(Language.FieldKeys.description, .string)
			.field(Language.FieldKeys.published, .bool, .required)
			.field(Language.FieldKeys.price, .double, .required)
			.create()
			
	}
	
	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.schema(Language.schema).delete()
	}
	
	
}

