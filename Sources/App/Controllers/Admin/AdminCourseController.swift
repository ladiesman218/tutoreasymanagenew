import Vapor
import Fluent

struct AdminCourseController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let courseAPI = routes.grouped([AdminUser.sessionAuthenticator(), AdminUser.guardMiddleware()]).grouped("api", "admin", "course")
		
		courseAPI.get(":id", use: getCourse)
		courseAPI.get(use: getAllCourses)
		courseAPI.post(use: save)
		courseAPI.post("delete", ":id", use: deleteCourse)
	}
	
	func getCourse(_ req: Request) async throws -> Course {
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		if let course = try await Course.find(id, on: req.db) {
			return course
		} else {
			throw CourseError.idNotFound(id: id)
		}
	}
	
	func getAllCourses(_ req: Request) async throws -> [Course] {
		return try await Course.query(on: req.db).all()
	}
	
	func save(_ req: Request) async throws -> HTTPStatus {
		let input = try req.content.decode(Course.Input.self)
		var errors = [DebuggableError]()
		try await input.validate(errors: &errors, req: req)
		guard errors.isEmpty else { throw errors.abort }

		guard let id = input.id else {
			// Creating a new course
			let course = input.generateCourse()
			try await course.create(on: req.db)
			return .created
		}
		// Updating an existing course
		let foundID = try await Course.find(id, on: req.db)!
		foundID.name = input.name
		foundID.description = input.description
		foundID.published = input.published
		foundID.price = input.price
		try await foundID.update(on: req.db)
		return .ok
	}
	
	func deleteCourse(_ req: Request) async throws -> HTTPStatus {
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		guard let course = try await Course.find(id, on: req.db) else {
			throw CourseError.idNotFound(id: id)
		}
		try await course.delete(on: req.db)
		return .ok
	}
}
