import Vapor
import Fluent

struct PublicLanguageController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let language = routes.grouped("api", "language")
        language.get(use: getAllLanguages)
        language.get(":id", use: getLanguage)
    }
    
	func getAllLanguages(_ req: Request) async throws -> [Language.PublicInfo] {
		return try await Language.query(on: req.db).all().compactMap { $0.publicList }
	}
	
	func getLanguage(_ req: Request) async throws -> Language.PublicInfo {
		guard let idString = req.parameters.get("id"), let id = Language.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		let language = try await Language.query(on: req.db).filter(\.$id == id).with(\.$courses).first()
		guard let language = language, language.published else {
			throw LanguageError.idNotFound(id: id)
		}
		// In order to convert associated courses to their publicInfo, we need to get each course's path. But a course's path rely on getting its language relationship then read the language's path, so despite we know all courses are children of the given language, we still have to either load language relationship from db, or set language manually here, that's a loop... Store course's path in database would fix this but that case if a language's name has changed, all associated courses' path should be modified in db, giving less flexibility.
		let courses = language.courses
		courses.forEach { $0.$language.value = language }
		return language.publicItem!	// lan is made sure published, so safe to use force unwrap here.
	}
}



