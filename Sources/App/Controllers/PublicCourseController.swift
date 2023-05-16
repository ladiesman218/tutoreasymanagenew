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
		
		let courses = try await Course.query(on: req.db).all().compactMap { $0.publicList }
		let eTagValue = String(describing: courses).persistantHash.description
		
		// Check if courses has been cached already and return NotModified response if the etags match
		if eTagValue == req.headers.first(name: .ifNoneMatch) {
			return Response(status: .notModified)
		}
		
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .eTag, value: eTagValue)
		let response = try await courses.encodeResponse(status: .ok, headers: headers, for: req)
		
		return response
	}
	
	// This will return course info with its all stages info
	func getCourse(_ req: Request) async throws -> Response {
		guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		guard let course = try await Course.find(id, on: req.db), let publicInfo = course.publicInfo else {
			throw CourseError.idNotFound(id: id)
		}
		
		guard FileManager.default.fileExists(atPath: course.directoryURL.path) else {
			throw CourseError.fileNotFound(name: course.name)
		}
		
		let eTagValue = String(describing: publicInfo).persistantHash.description
		// Check if course has been cached already and return NotModified response if the etags match
		if eTagValue == req.headers.first(name: .ifNoneMatch) {
			return Response(status: .notModified)
		}
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .eTag, value: eTagValue)
		
		let response = try await publicInfo.encodeResponse(status: .ok, headers: headers, for: req)
		return response
	}
	
	// This will return stage info with all its chapters
	func getAllChapters(_ req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()
		
		let stageURL = try await parseStageOrChapter(from: pathComponents, req: req, index: 2)
		let stage = Stage(directoryURL: stageURL).publicInfo
		let eTagValue = String(describing: stage).persistantHash.description
		
		// Check if stage has been cached already and return NotModified response if the etags match
		if eTagValue == req.headers.first(name: .ifNoneMatch) {
			return Response(status: .notModified)
		}
		
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .eTag, value: eTagValue)
		
		let response = try await stage.encodeResponse(status: .ok, headers: headers, for: req)
		return response
	}
	
	func getChapter(_ req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()
		
		let chapterURL = try await parseStageOrChapter(from: pathComponents, req: req, index: 3)
		let chapter = Chapter(directoryURL: chapterURL)
		
		let eTagValue = String(describing: chapter).persistantHash.description
		
		// Check if chapter has been cached already and return NotModified response if the etags match
		if eTagValue == req.headers.first(name: .ifNoneMatch) {
			return Response(status: .notModified)
		}
		
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .eTag, value: eTagValue)
		let response = try await chapter.encodeResponse(status: .ok, headers: headers, for: req)
		return response
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
			throw CourseError.fileNotFound(name: pathComponents.last!)
		}
		return url
	}
	
}
