import Vapor
import Fluent

final class Order: Model, Content {
	
	enum Status: String, Codable {
		// Canceled means user didn't make a successful payment within a limited time, or voluntarily clicked cancel button before making a payment.
		
		case unPaid = "UnPaid", completed = "Completed", canceled = "Canceled", deleted = "Deleted"
	}
	
	static var schema = "orders"
	
	struct FieldKeys {
		static let status = FieldKey(stringLiteral: "status")
		static let courseCaches = FieldKey(stringLiteral: "course_caches")
		static let user = FieldKey(stringLiteral: "user")
		static let paidAmount = FieldKey(stringLiteral: "paid_amount")
		
		static let generateTime = FieldKey(stringLiteral: "generate_time")
		static let completeTime = FieldKey(stringLiteral: "complete_time")
		static let cancelTime = FieldKey(stringLiteral: "cancel_Time")
		static let deleteTime = FieldKey(stringLiteral: "deleteTime")
	}
	
	@ID var id: UUID?
	@Enum(key: FieldKeys.status) var status: Status
	@Children(for: \CourseCache.$order) var items: [CourseCache]
	@Parent(key: FieldKeys.user) var user: User
	@Field(key: FieldKeys.paidAmount) var paidAmount: Int
	
	@Timestamp(key: FieldKeys.generateTime, on: .create) var generateTime: Date?
	@Timestamp(key: FieldKeys.completeTime, on: .none) var completeTime: Date?
	@Timestamp(key: FieldKeys.cancelTime, on: .none) var cancelTime: Date?
	@Timestamp(key: FieldKeys.deleteTime, on: .delete) var deleteTime: Date?
}


