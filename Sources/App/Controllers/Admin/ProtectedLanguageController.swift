import Vapor
import Fluent

struct ProtectedLanguageController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let lanAPI = routes.grouped([AdminUser.sessionAuthenticator(), AdminUser.guardMiddleware()]).grouped("api", "admin", "language")
		lanAPI.post(use: saveLanguage)
		lanAPI.get(use: getAllLanguages)
		lanAPI.get(":id", use: getLanguage)
		lanAPI.post("delete", ":id", use: deleteLanguage)
	}
	
	func getAllLanguages(_ req: Request) async throws -> [Language] {
		return try await Language.query(on: req.db).all()
	}

	func getLanguage(_ req: Request) async throws -> Language {
		guard let idString = req.parameters.get("id"), let id = Language.IDValue(uuidString: idString) else {
			throw GeneralInputError.invalidID
		}
		
		guard let language = try await Language.query(on: req.db).with(\.$courses).filter(\.$id == id).first() else { throw LanguageError.idNotFound(id: id)}
		
		return language
	}
	
	func saveLanguage(_ req: Request) async throws -> HTTPStatus {
		let input = try req.content.decode(Language.Input.self)
		var errors = [DebuggableError]()
		try await input.validate(errors: &errors, req: req)

		guard errors.isEmpty else { throw errors.abort }

		guard let id = input.id else {
			// Here we are creating a new language
			let language = input.generateLanguage()
			try await language.create(on: req.db)
			return .created
		}

		// Updating an existing course
		let foundID = try await Language.find(id, on: req.db)!
		foundID.name = input.name
		foundID.description = input.description
		foundID.published = input.published
		foundID.price = input.price
		foundID.annuallyIAPIdentifier = input.annuallyIAPIdentifier
		try await foundID.save(on: req.db)
		return .ok
	}
	
	func deleteLanguage(_ req: Request) async throws -> HTTPStatus {
		guard let idString = req.parameters.get("id"), let id = Language.IDValue(idString) else {
			throw GeneralInputError.invalidID
		}
		
		guard let language = try await Language.find(id, on: req.db) else {
			throw LanguageError.idNotFound(id: id)
		}
		try await language.delete(on: req.db)
		return .ok
	}
}
