import Vapor
import Fluent

struct PublicLanguageController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let language = routes.grouped("api", "language")
        language.get(use: getAllLanguages)
        language.get(":id", use: getLanguage)
    }
    
    func getAllLanguages(req: Request) -> EventLoopFuture<[Language.PublicInfo]> {
        Language.query(on: req.db).filter(\.$published == true).all().map { lans in
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
            
            // In order to convert associated courses to their publicInfo, we need to get each course's path. But a course's path rely on getting its language relationship then read the language's path, so despite we know all courses are children of the given language, we sitll have to load their language relationship here, that's a loop... Store course's path in database would fix this but that case if a language's name has changed, all associated courses' path should be modified in db, gives less flexibility.
            let courses = lan.courses
            return courses.map { $0.$language.load(on: req.db) }.flatten(on: req.eventLoop).map { _ in
                let publicList = courses.compactMap { $0.publicList }
                let final = Language.PublicInfo(id: id, name: lan.name, description: lan.description, price: lan.price, courses: publicList, directoryURL: lan.directoryURL, imagePath: lan.imagePath)
                return final
            }
        }
    }
}



