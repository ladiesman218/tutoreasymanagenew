import Vapor

func routes(_ app: Application) throws {
	app.get { req in
		return "Running"
	}
	try app.register(collection: AdminController())
	
	try app.register(collection: AdminCourseController())
	try app.register(collection: PublicCourseController())
	
	try app.register(collection: UserController())
	try app.register(collection: FileController())
	
	try app.register(collection: ProtectedOrderController())
	try app.register(collection: IAPController())
	try app.register(collection: AdminOrderController())
}
