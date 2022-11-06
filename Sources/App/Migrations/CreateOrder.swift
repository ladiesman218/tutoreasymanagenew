import Fluent
import FluentPostgresDriver

struct CreateOrder: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		let defaultStatus = SQLColumnConstraintAlgorithm.default(Order.Status.unPaid.rawValue)
		
		return database.enum(Order.FieldKeys.status.description)
			.case(Order.Status.unPaid.rawValue)
			.case(Order.Status.canceled.rawValue)
			.case(Order.Status.completed.rawValue)
			.case(Order.Status.deleted.rawValue)
			.create().flatMap { orderStatus in
				return database.schema(Order.schema)
					.id()
					.field(Order.FieldKeys.status, orderStatus, .required, .sql(defaultStatus))
					.field(Order.FieldKeys.user, .uuid, .required, .references(User.schema, .id))
					.field(Order.FieldKeys.courseCaches, .array(of: .uuid), .references(CourseCache.schema, .id), .required)
					.field(Order.FieldKeys.paidAmount, .int, .required)
					.field(Order.FieldKeys.generateTime, .datetime, .required)
					.field(Order.FieldKeys.cancelTime, .datetime)
					.field(Order.FieldKeys.completeTime, .datetime)
					.field(Order.FieldKeys.deleteTime, .datetime)
					.create()
			}
	}
	
	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.schema(Order.schema).delete().flatMap {
			database.schema(Order.FieldKeys.status.description).delete()
		}
	}
}
