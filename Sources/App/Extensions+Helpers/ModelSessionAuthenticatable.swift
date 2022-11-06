import Vapor
import Fluent

// Session authentication is only used for admin users now. Normal users use tokens to authenticate
extension ModelSessionAuthenticatable {
	func  unauthenticateAllSessions(id: SessionRecord.IDValue, req: Request, sessionDataKey: String) -> EventLoopFuture<Void> {
		let data = SessionData.init(initialData: [sessionDataKey: id.uuidString])
		
		var queue: [EventLoopFuture<Void>] = []
		return SessionRecord.query(on: req.db).filter(\.$data == data).all().map { sessions in
			sessions.forEach { session in
				session.data = [:]
				let job = session.save(on: req.db)
	//				let job = session.delete(on: req.db)
				queue.append(job)
			}
		}.flatMap {
			return queue.flatten(on: req.eventLoop)
		}
	}
}
