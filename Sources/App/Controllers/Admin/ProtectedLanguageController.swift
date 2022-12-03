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
	
	func getAllLanguages(req: Request) -> EventLoopFuture<[Language]> {
		return Language.query(on: req.db).with(\.$courses).all()
	}
	
	func getLanguage(req: Request) -> EventLoopFuture<Language> {
		guard let idString = req.parameters.get("id"), let id = Language.IDValue(uuidString: idString) else {
			return req.eventLoop.future(error: GeneralInputError.invalidID)
		}
		return Language.find(id, on: req.db).unwrap(or: LanguageError.idNotFound(id: id)).flatMap { lan in
			lan.$courses.load(on: req.db).transform(to: lan)
		}
	}
	
	func saveLanguage(req: Request) -> EventLoopFuture<Response> {
		
		var errors = [DebuggableError]()
		let input: Language.Input
		do {
			input = try req.content.decode(Language.Input.self)
		} catch {
			return req.eventLoop.future(error: error)
		}
		
		input.validate(errors: &errors)
		
		let queryID = Language.find(input.id, on: req.db).map { language -> Language? in
			if input.id != nil && language == nil {
				errors.append(LanguageError.idNotFound(id: input.id!))
			}
			return language
		}
		
		let queryName = Language.query(on: req.db).filter(\.$name == input.name).first().map { existedLanguage in
			if let existedLanguage = existedLanguage, existedLanguage.id != input.id {
				errors.append(LanguageError.languageNameExisted(name: input.name))
			}
		}
		
		return queryID.and(queryName).guard({ _ in errors.isEmpty }, else: errors.abort)
			.flatMap { foundLanguage, _ in
				
				guard let foundLanguage = foundLanguage else {
					let language = input.generateLanguage()
					return language.save(on: req.db).transform(to: HTTPStatus.created).encodeResponse(for: req)
				}
				
				// Here means we are updating an existing language
				foundLanguage.name = input.name
				foundLanguage.description = input.description
				foundLanguage.published = input.published
				foundLanguage.price = input.price
				return foundLanguage.save(on: req.db).transform(to: HTTPStatus.ok).encodeResponse(for: req)
			}
	}
	
	func deleteLanguage(req: Request) -> EventLoopFuture<Response> {
		guard let idString = req.parameters.get("id"), let id = Language.IDValue(idString) else {
			return req.eventLoop.future(error: GeneralInputError.invalidID)
		}
		
		return Language.find(id, on: req.db).unwrap(or: LanguageError.idNotFound(id: id)).flatMap { lan in
			lan.delete(force: true, on: req.db).transform(to: HTTPStatus.ok).encodeResponse(for: req)
		}
	}
}
