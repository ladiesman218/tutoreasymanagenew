import Vapor
import Fluent

// Session authentication is only used for admin users now. Normal users use tokens to authenticate
extension ModelSessionAuthenticatable {
	func  unauthenticateAllSessions(id: SessionRecord.IDValue, req: Request, sessionDataKey: String) -> EventLoopFuture<Void> {
		let data = SessionData.init(initialData: [sessionDataKey: id.uuidString])
		
		return SessionRecord.query(on: req.db).filter(\.$data == data).all().flatMap { sessions in
			sessions.forEach { $0.data = [:] }
			return sessions.map { $0.save(on: req.db) }.flatten(on: req.eventLoop)
		}
	}
}
