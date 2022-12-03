import Vapor
import Fluent

final class LanguageCache: Model {
	static let schema: String = "language_caches"
	
	struct FieldKeys {
		static let name = FieldKey(stringLiteral: "name")
		static let description = FieldKey(stringLiteral: "description")
		static let price = FieldKey(stringLiteral: "price")
		static let order = FieldKey(stringLiteral: "order_id")
	}
	
	@ID var id: UUID?
	@Field(key: LanguageCache.FieldKeys.name) var name: String
	@Field(key: LanguageCache.FieldKeys.description) var description: String
	@Field(key: LanguageCache.FieldKeys.price) var price: Double
	@Parent(key: LanguageCache.FieldKeys.order) var order: Order
	
	init() {}
	
	init(id: IDValue? = nil, name: String, description: String, price: Double, orderID: Order.IDValue) {
		self.id = id
		self.name = name
		self.description = description
		self.price = price
		self.$order.id = orderID
	}
	
	// LanguageCache should be initialized before order, so when init a LanguageCache, order id doesn't exist yet.
	init?(from language: Language, orderID: Order.IDValue) {
		guard let _  = try? language.requireID() else {
			return nil
		}		
		self.name = language.name
		self.description = language.description
		self.price = language.price
		self.$order.id = orderID
	}

}
