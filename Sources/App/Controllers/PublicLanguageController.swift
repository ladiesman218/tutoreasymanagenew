import Vapor
import Fluent

struct PublicLanguageController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let language = routes.grouped("api", "language")
        language.get(use: getAllLanguages)
        language.get(":id", use: getLanguage)
    }
    
    func getAllLanguages(req: Request) -> EventLoopFuture<[Language.PublicInfo]> {
        Language.query(on: req.db)/*.filter(\.$published == true)*/.all().map { lans in
            return lans.compactMap { $0.publicList }
        }
    }
    
    func getLanguage(req: Request) -> EventLoopFuture<Language.PublicInfo> {
        guard let idString = req.parameters.get("id"), let id = Language.IDValue(idString) else {
            return req.eventLoop.future(error: GeneralInputError.invalidID)
        }
        return Language.query(on: req.db).with(\.$courses).filter(\.$id == id).filter(\.$published == true).first().flatMap { lan -> EventLoopFuture<Language.PublicInfo> in
            guard let lan = lan else {
                return req.eventLoop.future(error: LanguageError.idNotFound(id: id))
            }
            
            // In order to convert associated courses to their publicInfo, we need to get each course's path. But a course's path rely on getting its language relationship then read the language's path, so despite we know all courses are children of the given language, we sitll have to either load language relationship from db, or set language manually here, that's a loop... Store course's path in database would fix this but that case if a language's name has changed, all associated courses' path should be modified in db, gives less flexibility.
            let courses = lan.courses
            courses.forEach { $0.$language.value = lan }
			let language = lan.publicItem!	// lan is made sure published, so safe to use force unwrap here.
			return req.eventLoop.future(language)
//			let language = Language.PublicInfo(id: id, name: lan.name, description: lan.description, price: lan.price, courses: courses.compactMap { $0.publicList }, directoryURL: lan.directoryURL, imagePath: lan.imagePath, appStoreID: lan.appStoreID)
//            return req.eventLoop.future(language)
        }
    }
}



