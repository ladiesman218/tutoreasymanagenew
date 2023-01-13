import Vapor
import Fluent

// Session authentication is only used for admin users now. Normal users use tokens to authenticate
extension ModelSessionAuthenticatable {
	func  unauthenticateAllSessions(id: SessionRecord.IDValue, req: Request, sessionDataKey: String) async throws {
		let data = SessionData.init(initialData: [sessionDataKey: id.uuidString])
		let records = try await SessionRecord.query(on: req.db).filter(\.$data == data).all()
		
		records.forEach { $0.data = [:] }
		
		return await withThrowingTaskGroup(of: Void.self) { group in
			records.forEach { record in
				group.addTask {
					try await record.save(on: req.db)
				}
			}
		}
	}
}
