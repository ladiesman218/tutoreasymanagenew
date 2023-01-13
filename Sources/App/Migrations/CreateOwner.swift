import Fluent
import Vapor

struct CreateOwner: AsyncMigration {
	
	func prepare(on database: Database) async throws {
		let passwordHash = try Bcrypt.hash("asdf1234")
		let owner = AdminUser(email: "chn_dunce@126.com", username: "dunce", password: passwordHash, isAccepted: true, type: .shopOwner)
		try await owner.create(on: database)
	}
	
	func revert(on database: Database) async throws {
		try await AdminUser.query(on: database).filter(\.$username == "dunce").delete()
	}
}

