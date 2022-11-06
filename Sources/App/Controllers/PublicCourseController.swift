import Vapor
import Fluent

struct PublicCourseController: RouteCollection {
	
	func boot(routes: RoutesBuilder) throws {
		let courses = routes.grouped("api", "course")
		
		courses.get(use: getAllCourse)
		courses.get(":id", use: getCourse)
	}
	
	func getAllCourse(req: Request) -> EventLoopFuture<[Course.PublicInfo]> {
		return Course.query(on: req.db)/*.filter(\.$published == true)*/.with(\.$language).all().map { courses in
			courses.compactMap { $0.publicList }
		}
	}
	
	func getCourse(req: Request) -> EventLoopFuture<Course.PublicInfo> {
		
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			return req.eventLoop.future(error: GeneralInputError.invalidID)
		}
		
        return Course.query(on: req.db).filter(\.$id == id).filter(\.$published == true).with(\.$language).first().unwrap(or: CourseError.idNotFound(id: id)).map { return $0.publicInfo! }
	}
}

