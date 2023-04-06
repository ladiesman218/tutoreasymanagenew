import Vapor
import Fluent

struct PublicCourseController: RouteCollection {
	
	func boot(routes: RoutesBuilder) throws {
		let courseRoute = routes.grouped("api", "course")
		
		courseRoute.get(use: getAllCourses)
		courseRoute.get(":id", use: getCourse)
		
		let stageRoute = routes.grouped("api", "stage")
		stageRoute.get("**", use: getAllChapters)
	}

	func getAllCourses(_ req: Request) async throws -> [Course.PublicInfo] {
		return try await Course.query(on: req.db).all().compactMap { $0.publicList }
	}
		
	// This will return course info with its all stages info
	func getCourse(_ req: Request) async throws -> Course.PublicInfo {
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		if let course = try await Course.find(id, on: req.db), course.published {
			guard FileManager.default.fileExists(atPath: course.directoryURL.path) else {
				throw CourseError.noDirectoryFound(name: course.name)
			}
			return course.publicInfo!
		} else {
			throw CourseError.idNotFound(id: id)
		}
	}
	
	// This will return stage info with all its chapters
	func getAllChapters(_ req: Request) async throws -> Stage.PublicInfo {
		let pathComponents = req.parameters.getCatchall()
		
		let count = pathComponents.count
		// Second to last in pathComponent should be the couse name, make sure pathComponent has that many item otherwise app will crash when trying to get that index
		guard count >= 2 else { throw GeneralInputError.invalidURL }
		let courseName = pathComponents[count - 2]
		// Make sure course is published
		guard try await Course.query(on: req.db).group(.and, { group in
			group.filter(\.$name == courseName).filter(\.$published == true)
		}).first() != nil else {
			throw CourseError.nameNotFound(name: courseName)
		}
		let stageURL = try pathComponents.generateURL()
		guard FileManager.default.fileExists(atPath: stageURL.path) else {
			throw CourseError.noDirectoryFound(name: pathComponents.last!)
		}
		let stage = Stage(directoryURL: stageURL)
		return stage.publicInfo
	}
	
}
