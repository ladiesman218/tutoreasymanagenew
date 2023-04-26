import Vapor
import Fluent

struct PublicCourseController: RouteCollection {
	
	func boot(routes: RoutesBuilder) throws {
		let courseRoute = routes.grouped("api", "course")
		
		courseRoute.get(use: getAllCourses)
		courseRoute.get(":id", use: getCourse)
		
		let stageRoute = routes.grouped("api", "stage")
		stageRoute.get("**", use: getAllChapters)
		
		let chapterRoute = routes.grouped("api", "chapter").grouped(Token.authenticator())
		chapterRoute.get("**", use: getChapter)
	}

	func getAllCourses(_ req: Request) async throws -> Response {
		var headers = HTTPHeaders()
		let courses = try await Course.query(on: req.db).all().compactMap { $0.publicList }
		headers.add(name: .eTag, value: courses.hashValue.description)
		return try await Course.query(on: req.db).all().compactMap { $0.publicList}.encodeResponse(status: .ok, headers: headers, for: req)
	}
		
	// This will return course info with its all stages info
	func getCourse(_ req: Request) async throws -> Response {
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		if let course = try await Course.find(id, on: req.db), course.published {
			guard FileManager.default.fileExists(atPath: course.directoryURL.path) else {
				throw CourseError.noDirectoryFound(name: course.name)
			}
			var headers = HTTPHeaders()
			headers.add(name: .eTag, value: course.publicInfo!.hashValue.description)
			return try await course.publicInfo!.encodeResponse(status: .ok, headers: headers, for: req)
		} else {
			throw CourseError.idNotFound(id: id)
		}
	}
	
	// This will return stage info with all its chapters
	func getAllChapters(_ req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()
		
		let stageURL = try await parseStageOrChapter(from: pathComponents, req: req, index: 2)
		let stage = Stage(directoryURL: stageURL)
		
		var headers = HTTPHeaders()
		headers.add(name: .eTag, value: stage.publicInfo.hashValue.description)
		return try await stage.publicInfo.encodeResponse(status: .ok, headers: headers, for: req)
	}
	
	func getChapter(_ req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()

		let chapterURL = try await parseStageOrChapter(from: pathComponents, req: req, index: 3)
		let chapter = Chapter(directoryURL: chapterURL)
		
		var headers = HTTPHeaders()
		headers.add(name: .eTag, value: chapter.hashValue.description)
		return try await chapter.encodeResponse(status: .ok, headers: headers, for: req)
	}
	
	func parseStageOrChapter(from pathComponents: [String], req: Request, index: Int) async throws -> URL {
		// coursesDirectoryName is where we put all course files, currently it's 'courses', following should be the name of the course, next should be the name for each stage's folder, then the name for chapter's folder, nothing else should follow. Make sure the pathComponents contains the right number of items in step 1.
		guard let coursesDirIndex = pathComponents.firstIndex(of: coursesDirectoryName), pathComponents.count == coursesDirIndex + index + 1 else {
			throw GeneralInputError.invalidURL
		}
		
		// Make sure course is published
		let courseName = pathComponents[coursesDirIndex + 1]
		guard try await Course.query(on: req.db).group(.and, { group in
			group.filter(\.$name == courseName).filter(\.$published == true)
		}).first() != nil else {
			throw CourseError.nameNotFound(name: courseName)
		}
		
		let url = try pathComponents.generateURL()
		guard FileManager.default.fileExists(atPath: url.path) else {
			throw CourseError.noDirectoryFound(name: pathComponents.last!)
		}
		return url
	}
	
}
