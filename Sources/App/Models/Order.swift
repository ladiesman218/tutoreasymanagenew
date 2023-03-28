import Vapor
import Fluent

final class Order: Model, Content {
	
	// To generate an order, first query all associated course's id, generate courseCaches based on the found results, then save the caches along with the user and other order info in db. Upon successful saving, start a timer, after given time period(15 mins for example), the order status should be changed to canceled automatically if hasn't been changed to completed already.
	#warning("After a longer time period(1 month for example), db should automatically purge all unpaid and canceled orders.")
	enum Status: String, Codable {
		// Canceled means user didn't make a successful payment within a limited time, or voluntarily clicked cancel button before making a payment.
		// Completed means user has made a payment
		
		case unPaid = "UnPaid", completed = "Completed", canceled = "Canceled", refunded = "Refunded"
	}
	
	static var schema = "orders"
	
	struct FieldKeys {
		static let id = FieldKey(stringLiteral: "id")	// This is created for courseCache migration referrence
		static let status = FieldKey(stringLiteral: "status")
		static let courseCaches = FieldKey(stringLiteral: "course_caches")
		static let user = FieldKey(stringLiteral: "user_id")
		static let paymentAmount = FieldKey(stringLiteral: "payment_amount")
		static let originalTransactionID = FieldKey(stringLiteral: "original_transaction_id")
		static let transactionID = FieldKey(stringLiteral: "transaction_id")
		static let iapIdentifier = FieldKey(stringLiteral: "iap_identifier")

		static let generateTime = FieldKey(stringLiteral: "generate_time")
		static let completeTime = FieldKey(stringLiteral: "complete_time")
		static let cancelTime = FieldKey(stringLiteral: "cancel_time")
		static let refundTime = FieldKey(stringLiteral: "refund_time")
		static let expirationTime = FieldKey(stringLiteral: "expiration_time")
	}
	
	@ID var id: UUID?
	@Enum(key: FieldKeys.status) var status: Status
	@Field(key: FieldKeys.courseCaches) var items: [CourseCache]
	@Parent(key: FieldKeys.user) var user: User
	@Field(key: FieldKeys.paymentAmount) var paymentAmount: Float
	@OptionalField(key: FieldKeys.originalTransactionID) var originalTransactionID: String?
	@Field(key: FieldKeys.transactionID) var transactionID: String
	// Only used for apple platforms, so it's optional
	@OptionalField(key: FieldKeys.iapIdentifier) var iapIdentifier: String?
	
	@Timestamp(key: FieldKeys.generateTime, on: .create) var generateTime: Date?
	@Timestamp(key: FieldKeys.completeTime, on: .none) var completeTime: Date?
	@Timestamp(key: FieldKeys.cancelTime, on: .none) var cancelTime: Date?
	@Timestamp(key: FieldKeys.refundTime, on: .none) var refundTime: Date?
	@Timestamp(key: FieldKeys.expirationTime, on: .none) var expirationTime: Date?
	
	init() {}
	
	init(id: IDValue? = nil, status: Status = .unPaid, courseCaches: [CourseCache], userID: User.IDValue, paymentAmount: Float, originalTransactionID: String? = nil, transactionID: String, iapIdentifier: String? = nil, generateTime: Date = Date(), completeTime: Date? = nil, cancelTime: Date? = nil, refundTime: Date? = nil, expirationTime: Date? = nil) {
		self.id = id
		self.status = status
		self.items = courseCaches
		self.$user.id = userID
		self.paymentAmount = paymentAmount
		self.originalTransactionID = originalTransactionID
		self.transactionID = transactionID
		self.iapIdentifier = iapIdentifier
		self.generateTime = generateTime
		self.completeTime = completeTime
		self.cancelTime = cancelTime
		self.refundTime = refundTime
		self.expirationTime = expirationTime
	}
}

extension Order {
	struct Input: Decodable {
		let courseIDs: [Course.IDValue]
	}
}
