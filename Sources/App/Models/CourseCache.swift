import Vapor
import Fluent

final class CourseCache: Model {
	static let schema: String = "course_cache"
	
	struct FieldKeys {
		static let name = FieldKey(stringLiteral: "name")
		static let description = FieldKey(stringLiteral: "description")
		static let price = FieldKey(stringLiteral: "price")
		static let order = FieldKey(stringLiteral: "order_id")
		
	}
	
	@ID var id: UUID?
	@Field(key: CourseCache.FieldKeys.name) var name: String
	@Field(key: CourseCache.FieldKeys.price) var price: Double
	@Field(key: CourseCache.FieldKeys.description) var description: String
	@Parent(key: CourseCache.FieldKeys.order) var order: Order
	
	init() {}
	
	init(id: IDValue? = nil, name: String, price: Double, description: String, orderID: Order.IDValue) {
		self.id = id
		self.name = name
		self.price = price
		self.description = description
		self.$order.id = orderID
	}
}

