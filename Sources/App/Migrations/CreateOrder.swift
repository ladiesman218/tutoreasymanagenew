import Fluent
import FluentPostgresDriver

#warning("get payment amount and save it")
struct CreateOrder: AsyncMigration {
	func prepare(on database: Database) async throws {
		let defaultStatus = SQLColumnConstraintAlgorithm.default(Order.Status.unPaid.rawValue)
		
		let orderStatus = try await database.enum(Order.FieldKeys.status.description)
			.case(Order.Status.unPaid.rawValue)
			.case(Order.Status.cancelled.rawValue)
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
			.field(Order.FieldKeys.refundAmount, .double)
			.field(Order.FieldKeys.iapIdentifier, .string)
			.field(Order.FieldKeys.generateTime, .datetime, .required)
			.field(Order.FieldKeys.completeTime, .datetime)
			.field(Order.FieldKeys.cancelTime, .datetime)
			.field(Order.FieldKeys.refundTime, .datetime)
			.field(Order.FieldKeys.expirationTime, .datetime)
			.create()

		// When order status is completed, complete_time can't be empty, also expiration time should be later than complete time.
		let completeTimeRaw = SQLRaw(" \(Order.FieldKeys.status) != '\(Order.Status.completed.rawValue)' OR \(Order.FieldKeys.status) = '\(Order.Status.completed.rawValue)' AND \(Order.FieldKeys.completeTime) IS NOT NULL AND \(Order.FieldKeys.expirationTime) IS NOT NULL AND \(Order.FieldKeys.expirationTime) > \(Order.FieldKeys.completeTime)")
		let completeTimeConstraint = SQLTableConstraintAlgorithm.check(completeTimeRaw)
		let completedTime = DatabaseSchema.Constraint.sql(completeTimeConstraint)
		// Refunded order must set a refund time, also refundAmount can't be empty
		let refundTimeRaw = SQLRaw("\(Order.FieldKeys.status) != '\(Order.Status.refunded.rawValue)' OR \(Order.FieldKeys.status) = '\(Order.Status.refunded.rawValue)' AND \(Order.FieldKeys.refundTime) IS NOT NULL AND \(Order.FieldKeys.refundAmount) IS NOT NULL")
		let refundTimeConstraint = SQLTableConstraintAlgorithm.check(refundTimeRaw)
		let refundTime = DatabaseSchema.Constraint.sql(refundTimeConstraint)
		// Cancelled order must set a cancel time, and it shouldn't have a complete time
		let cancelledTimeRaw = SQLRaw("\(Order.FieldKeys.status) != '\(Order.Status.cancelled.rawValue)' OR \(Order.FieldKeys.status) = '\(Order.Status.cancelled.rawValue)' AND \(Order.FieldKeys.cancelTime) IS NOT NULL AND \(Order.FieldKeys.completeTime) IS NULL")
		let cancelTimeConstraint = SQLTableConstraintAlgorithm.check(cancelledTimeRaw)
		let cancelTime = DatabaseSchema.Constraint.sql(cancelTimeConstraint)
		
		try await database.schema(Order.schema).constraint(completedTime).constraint(refundTime).constraint(cancelTime).update()
	}
	
	func revert(on database: Database) async throws {
		try await database.schema(Order.schema).delete()
		try await database.schema(Order.FieldKeys.status.description).delete()
	}
}
