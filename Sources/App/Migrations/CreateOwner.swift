import Fluent
import Vapor

struct CreateOwner: Migration {
	
  func prepare(on database: Database) -> EventLoopFuture<Void> {
	let passwordHash: String
	
	do {
	  passwordHash = try Bcrypt.hash("asdf1234")
	} catch {
	  return database.eventLoop.future(error: error)
	}
	let owner = AdminUser(email: "chn_dunce@126.com", username: "dunce", password: passwordHash, isAccepted: true, type: .shopOwner)

	return owner.create(on: database)
  }
  
  func revert(on database: Database) -> EventLoopFuture<Void> {
	AdminUser.query(on: database).filter(\.$username == "dunce").delete()
  }
}

