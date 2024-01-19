import Vapor
import Fluent

struct PublicCourseController: RouteCollection {
	
	enum DirectoryType: Int {
		case stage = 2
		case chapter = 3
	}
	
	func boot(routes: RoutesBuilder) throws {
		let courseRoute = routes.grouped("api", "course")
		
		courseRoute.get(use: getAllCourses)
		courseRoute.get(":id", use: getCourse)
		
		let stageRoute = routes.grouped("api", "stage")
		stageRoute.get("**", use: getStage)
		
		let chapterRoute = routes.grouped("api", "chapter")
		chapterRoute.get("**", use: getChapter)
	}
	
	func getAllCourses(_ req: Request) async throws -> Response {
		let courses = try await Course.query(on: req.db).all().compactMap { $0.publicList }
		return try await req.response(of: courses)
	}
	
	// This will return course info with all its stages' urls, currently sorted by their names
#warning("Add functionality to sort stages per need")
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
		
		return try await req.response(of: publicInfo)
	}
	
	// This will return stage info with all its chapter's directory urls, sorted by chapterPrefixRegex's int value
	func getStage(_ req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()
		
		let stageURL = try await parseStageOrChapter(from: pathComponents, req: req, type: .stage)
		let stage = Stage(directoryURL: stageURL).publicInfo
		return try await req.response(of: stage)
	}
	
	func getChapter(_ req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()
		
		let chapterURL = try await parseStageOrChapter(from: pathComponents, req: req, type: .chapter)
		let chapter = Chapter(directoryURL: chapterURL)
		
		return try await req.response(of: chapter)
	}
	

	func parseStageOrChapter(from pathComponents: [String], req: Request, type: DirectoryType) async throws -> URL {
		// coursesDirectoryName is where we put all course files, currently it's 'courses', following should be the name of the course, next should be the name for each stage's folder, then the name for chapter's folder, nothing else should follow. Make sure the pathComponents contains the right number of items in step 1.
		guard let coursesDirIndex = pathComponents.firstIndex(of: coursesDirectoryName), pathComponents.count == coursesDirIndex + type.rawValue + 1 else {
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
