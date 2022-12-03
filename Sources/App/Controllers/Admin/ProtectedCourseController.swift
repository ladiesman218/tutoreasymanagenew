import Vapor
import Fluent

struct ProtectedCourseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let courseAPI = routes.grouped([AdminUser.sessionAuthenticator(), AdminUser.guardMiddleware()]).grouped("api", "admin", "course")
        
        courseAPI.get(":id", use: getCourse)
        courseAPI.get(use: getAllCourses)
        courseAPI.post(use: save)
        courseAPI.post("delete", ":id", use: deleteCourse)
    }
    
    func getCourse(req: Request) -> EventLoopFuture<Course> {
        guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
            return req.eventLoop.future(error: GeneralInputError.invalidID)
        }
        
        return Course.find(id, on: req.db).unwrap(or: CourseError.idNotFound(id: id)).flatMap { course in
            course.$language.load(on: req.db).transform(to: course)
        }
    }
    
    func getAllCourses(req: Request) -> EventLoopFuture<[Course]> {
        return Course.query(on: req.db).with(\.$language).all()
    }
    
    func save(req: Request) -> EventLoopFuture<Response> {
        let input: Course.Input
        var errors = [DebuggableError]()
        
        do {
            input = try req.content.decode(Course.Input.self)
        } catch {
            return req.eventLoop.future(error: error)
        }
        
        input.validate(errors: &errors)
        
        let queryID = Course.find(input.id, on: req.db).map { foundCourse -> Course? in
            if input.id != nil && foundCourse == nil {
                errors.append(CourseError.idNotFound(id: input.id!))
            }
            return foundCourse
        }
        
		let queryLanguage = Language.find(input.languageID, on: req.db).map { language in
            if language == nil {
                errors.append(LanguageError.idNotFound(id: input.languageID))
            }
        }
        
        let queryName = Course.query(on: req.db).filter(\.$name == input.name).first().map { foundName in
            // When changing an existing course's name to a new value, input.id must have a value, but the foundName is nil so these 2 won't be equal, so pre-condition the following expression with a check to see if foundName is nil first. Only check foundName's id and input.id if a name is already found.
            if foundName != nil && foundName?.id != input.id {
                errors.append(CourseError.courseNameExisted(name: input.name))
            }
        }
		
		return queryName.and(queryLanguage).and(queryID).guard({ _ in
			errors.isEmpty
		}, else: errors.abort).flatMap { _, foundCourse in

			guard let foundCourse = foundCourse else {
				let course = input.generateCourse()
				return course.save(on: req.db).transform(to: HTTPStatus.created).encodeResponse(for: req)
			}
			
			// Here means updating an existed course
			foundCourse.name = input.name
			foundCourse.description = input.description
			foundCourse.published = input.published
			foundCourse.freeChapters = Array(Set(input.freeChapters)).sorted()	// When pre-editing an course hasn't been fully uploaded, allow set free chapter values greater than current chapters, eg: free chapter can contain number 80, but currently only 10 chapters has been uploaded.
			foundCourse.$language.id = input.languageID
			return foundCourse.save(on: req.db).transform(to: HTTPStatus.ok).encodeResponse(for: req)
		}

    }
    
    func deleteCourse(req: Request) -> EventLoopFuture<Response> {
        guard let idString = req.parameters.get("id"), let id = Course.IDValue(idString) else {
            return req.eventLoop.future(error: GeneralInputError.invalidID)
        }
        
        return Course.find(id, on: req.db).unwrap(or: CourseError.idNotFound(id: id)).flatMap { course in
            course.delete(on: req.db).transform(to: HTTPStatus.ok).encodeResponse(for: req)
        }
    }
}
