import Fluent
import FluentPostgresDriver

#warning("get payment amount and save it")
struct CreateOrder: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		let defaultStatus = SQLColumnConstraintAlgorithm.default(Order.Status.unPaid.rawValue)
		
		return database.enum(Order.FieldKeys.status.description)
			.case(Order.Status.unPaid.rawValue)
			.case(Order.Status.canceled.rawValue)
			.case(Order.Status.completed.rawValue)
			.case(Order.Status.refunded.rawValue)
			.create().flatMap { orderStatus in
				return database.schema(Order.schema)
					.id()
					.field(Order.FieldKeys.status, orderStatus, .required, .sql(defaultStatus))
					.field(Order.FieldKeys.languageCaches, .array(of: .dictionary), .required)
					.field(Order.FieldKeys.user, .uuid, .required, .references(User.schema, .id))
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
	}
	
	func revert(on database: Database) -> EventLoopFuture<Void> {
		database.schema(Order.schema).delete().flatMap {
			database.schema(Order.FieldKeys.status.description).delete()
		}
	}
}
