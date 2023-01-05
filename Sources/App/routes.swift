import Vapor

func routes(_ app: Application) throws {
	app.get { req in
		return "Running"
	}
	try app.register(collection: AdminController())
	
	try app.register(collection: ProtectedLanguageController())
	try app.register(collection: PublicLanguageController())
	
	try app.register(collection: ProtectedCourseController())
	try app.register(collection: PublicCourseController())
	
	try app.register(collection: UserController())
	try app.register(collection: PublicFileController())
	
	try app.register(collection: ProtectedOrderController())
	try app.register(collection: IAPController())
}
