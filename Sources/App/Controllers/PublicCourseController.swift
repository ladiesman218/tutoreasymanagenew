import Vapor
import Fluent

struct PublicCourseController: RouteCollection {
	
	func boot(routes: RoutesBuilder) throws {
		let courses = routes.grouped("api", "course")
		
		courses.get(use: getAllCourses)
		courses.get(":id", use: getCourse)
	}

	func getAllCourses(_ req: Request) async throws -> [Course.PublicInfo] {
		return try await Course.query(on: req.db).with(\.$language).all().compactMap { $0.publicList }
	}
		
	func getCourse(_ req: Request) async throws -> Course.PublicInfo {
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		let course = try await Course.query(on: req.db).filter(\.$id == id).with(\.$language).first()
		guard let course = course, course.published else {
			throw CourseError.idNotFound(id: id)
		}
		return course.publicInfo!
	}
}

