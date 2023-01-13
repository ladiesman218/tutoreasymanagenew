import Fluent
import FluentPostgresDriver

struct CreateCourse: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema(Course.schema).id()
			.field(Course.FieldKeys.name, .string, .required).unique(on: Course.FieldKeys.name)
			.field(Course.FieldKeys.description, .string)
			.field(Course.FieldKeys.published, .bool, .required)
			.field(Course.FieldKeys.language, .uuid, .required, .references(Language.schema, Language.FieldKeys.id, onDelete: .cascade))
			.field(Course.FieldKeys.freeChapters, .array(of: .int))
			.create()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(Course.schema).delete()
	}
}
