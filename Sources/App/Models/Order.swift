import Vapor
import Fluent

final class Order: Model, Content {
	
	// To generate an order, first query all associated language' id, generate languageCaches based on the found results, then save the caches along with the user and other order info in db. Upon successful saving, start a timer, after given time period(15 mins for example), the order status should be changed to canceled automatically if hasn't been changed to completed already.
	// After a longer time period(1 month for example), db should automatically purge all canceled orders.
	// When deleting an order, remove all associated languageCaches, this should be made sure in both controller and db constraint. When deleting a user, delete all its orders.
	enum Status: String, Codable {
		// Canceled means user didn't make a successful payment within a limited time, or voluntarily clicked cancel button before making a payment.
		// Completed means user has made a payment
		
		case unPaid = "UnPaid", completed = "Completed", canceled = "Canceled", refunded = "refunded"
	}
	
	static var schema = "orders"
	
	struct FieldKeys {
		static let id = FieldKey(stringLiteral: "id")	// This is created for LanguageCache migration referrence
		static let status = FieldKey(stringLiteral: "status")
		static let languageCaches = FieldKey(stringLiteral: "language_caches")
		static let user = FieldKey(stringLiteral: "user_id")
		static let paymentAmount = FieldKey(stringLiteral: "payment_amount")
		
		static let generateTime = FieldKey(stringLiteral: "generate_time")
		static let completeTime = FieldKey(stringLiteral: "complete_time")
		static let cancelTime = FieldKey(stringLiteral: "cancel_time")
		static let refundTime = FieldKey(stringLiteral: "refund-time")
	}
	
	@ID var id: UUID?
	@Enum(key: FieldKeys.status) var status: Status
	@Children(for: \LanguageCache.$order) var items: [LanguageCache]
	@Parent(key: FieldKeys.user) var user: User
	@Field(key: FieldKeys.paymentAmount) var paymentAmount: Double
	
	@Timestamp(key: FieldKeys.generateTime, on: .create) var generateTime: Date?
	@Timestamp(key: FieldKeys.completeTime, on: .none) var completeTime: Date?
	@Timestamp(key: FieldKeys.cancelTime, on: .none) var cancelTime: Date?
	@Timestamp(key: FieldKeys.refundTime, on: .none) var refundTime: Date?
	
	init() {}
	
	init(id: IDValue? = nil, status: Status = .unPaid, userID: User.IDValue, paymentAmount: Double, generateTime: Date = Date(), completeTime: Date? = nil, cancelTime: Date? = nil, refundTime: Date? = nil) {
		self.id = id
		self.status = status

		self.$user.id = userID
		self.paymentAmount = paymentAmount
		self.generateTime = generateTime
		self.completeTime = completeTime
		self.cancelTime = cancelTime
		self.refundTime = refundTime
	}
}

extension Order {
	struct Input: Decodable {
		let languageIDs: [Language.IDValue]
	}
}
