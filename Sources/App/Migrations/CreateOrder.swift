import Fluent
import FluentPostgresDriver

#warning("get payment amount and save it")
struct CreateOrder: AsyncMigration {
	func prepare(on database: Database) async throws {
		let defaultStatus = SQLColumnConstraintAlgorithm.default(Order.Status.unPaid.rawValue)
		
		let orderStatus = try await database.enum(Order.FieldKeys.status.description)
			.case(Order.Status.unPaid.rawValue)
			.case(Order.Status.canceled.rawValue)
			.case(Order.Status.completed.rawValue)
			.case(Order.Status.refunded.rawValue)
			.create()
		
		try await database.schema(Order.schema).id()
			.field(Order.FieldKeys.status, orderStatus, .required, .sql(defaultStatus))
			.field(Order.FieldKeys.courseCaches, .array(of: .dictionary), .required)
			.field(Order.FieldKeys.user, .uuid, .required, .references(User.schema, .id, onDelete: .cascade))
			.field(Order.FieldKeys.paymentAmount, .double, .required)
			.field(Order.FieldKeys.originalTransactionID, .string)
			.field(Order.FieldKeys.transactionID, .string)
			.field(Order.FieldKeys.iapIdentifier, .string)
			.field(Order.FieldKeys.generateTime, .datetime, .required)
			.field(Order.FieldKeys.completeTime, .datetime)
			.field(Order.FieldKeys.cancelTime, .datetime)
			.field(Order.FieldKeys.refundTime, .datetime)
			.field(Order.FieldKeys.expirationTime, .datetime)
			.create()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(Order.schema).delete()
		try await database.schema(Order.FieldKeys.status.description).delete()
	}
}
