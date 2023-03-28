import Vapor
import Fluent

final class Token: Model, Content {
	static let schema = "tokens"
	
	struct FieldKeys {
		static let value: FieldKey = .string("value")
		static let userID: FieldKey = .string("user_id")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.value) var value: String
	@Parent(key: FieldKeys.userID) var user: User
	
	init() {}
	
	init(id: Token.IDValue? = nil, value: String, userID: User.IDValue) {
		self.id = id
		self.value = value
		self.$user.id = userID
	}
}

extension Token {
	static func generate(for userID: User.IDValue) -> Token {
		let random = [UInt8].random(count: 16).base64
		return Token(value: random, userID: userID)
	}
	
	static func invalidateAll(userID: User.IDValue, req: Request) async throws {
		let tokens = try await Token.query(on: req.db).filter(\.$user.$id == userID).all()
		return await withThrowingTaskGroup(of: Void.self) { group in
			tokens.forEach { token in
				group.addTask {
					try await token.delete(on: req.db)
				}
			}
		}
	}
}

extension Token: ModelTokenAuthenticatable {
	static let valueKey = \Token.$value
	static let userKey = \Token.$user
	typealias User = App.User
	var isValid: Bool {
		true
	}
}
