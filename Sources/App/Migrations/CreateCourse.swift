import Fluent
import FluentKit
import FluentPostgresDriver
import FluentSQL

struct CreateCourse: AsyncMigration {
	
	func prepare(on database: Database) async throws {
		let defaultNotPublished = SQLColumnConstraintAlgorithm.default(false)
		
		try await database.schema(Course.schema).id()
			.field(Course.FieldKeys.name, .string, .required).unique(on: Course.FieldKeys.name)
			.field(Course.FieldKeys.description, .string)
			.field(Course.FieldKeys.price, .float, .required)
			.field(Course.FieldKeys.annuallyIAPIdentifier, .string, .required).unique(on: Course.FieldKeys.annuallyIAPIdentifier)
			.field(Course.FieldKeys.published, .bool, .sql(defaultNotPublished), .required)
			
			.create()
		
		// Add constraint, if published is true, iapIdentifier couldn't be empty. In raw SQL this should be:
		// ALTER TABLE courses ADD CONSTRAINT published_iap CHECK (NOT (published = TRUE AND annually_iap_identifier = ''));
		
		let raw = SQLRaw("NOT (published = TRUE AND annually_iap_identifier = '')")
		let tableConstraint = SQLTableConstraintAlgorithm.check(raw)
		let publishedNotEmpty = DatabaseSchema.Constraint.sql(tableConstraint)
		try await database.schema(Course.schema).constraint(publishedNotEmpty).update()

	}
	
	func revert(on database: Database) async throws {
		try await database.schema(Course.schema).delete()
	}
}
