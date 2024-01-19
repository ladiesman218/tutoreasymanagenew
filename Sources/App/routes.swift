import Vapor
import Fluent

func routes(_ app: Application) throws {
    app.get { req in
        return "Running"
    }
	
	// Save APNS tokens in db for Apple devices.
	app.post("api", "apns") { req -> HTTPStatus in
		let dto = try req.content.decode(APNSDevice.DTO.self)
		
		if let foundDevice = try await APNSDevice.query(on: req.db).filter(\.$deviceID == dto.deviceID).first() {
			foundDevice.token = dto.token
			foundDevice.$user.id = dto.userID
			try await foundDevice.save(on: req.db)
			return .ok
		} else {
			let token = APNSDevice(token: dto.token, userID: dto.userID, deviceID: dto.deviceID)
			try await token.save(on: req.db)
			return .created
		}
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
