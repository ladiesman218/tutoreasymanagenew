import Vapor
import Fluent

struct UserController: RouteCollection {
	
    let imageFolder = "ProfilePictures/"
    
	func boot(routes: RoutesBuilder) throws {
		let publicUsersAPI = routes.grouped("api", "user")
		publicUsersAPI.post("register", use: register)
		
		let protectedUsersAPI = publicUsersAPI.grouped(User.authenticator(), Token.authenticator())
		protectedUsersAPI.post("login", use: login)
		protectedUsersAPI.post("logout", use: logout)
		
		let tokenAuthGroup = publicUsersAPI.grouped(Token.authenticator(), User.guardMiddleware())
		tokenAuthGroup.get("public-info", use: getPublicUserInfo)
        tokenAuthGroup.on(.POST, "profile-pic", body: .collect(maxSize: "10mb") , use: uploadProfilePic)
	}
	
	func register(_ req: Request) async throws -> HTTPStatus {
		var errors: [DebuggableError] = []
		let input = try req.content.decode(User.RegisterInput.self)
		try await input.validate(errors: &errors, req: req)
		guard errors.isEmpty else { throw errors.abort }
		let hashedPassword = try Bcrypt.hash(input.password1)
		let user = User(email: input.email, username: input.username, firstName: input.firstName, lastName: input.lastName, password: hashedPassword, profilePic: nil)
		try await user.create(on: req.db)
		return .created
	}
	
	#warning("test")
	func login(_ req: Request) async throws -> Token {
		
		let userID = try req.auth.require(User.self).requireID()
//		let userID = user.id!
		try await Token.invalidateAll(userID: userID, req: req)
		let token = Token.generate(for: userID)
		try await token.save(on: req.db)
		return token
	}
	
	#warning("test")
	func logout(_ req: Request) async throws -> HTTPStatus {
		let userID = try req.auth.require(User.self).requireID()
		try await Token.invalidateAll(userID: userID, req: req)
		req.auth.logout(User.self)
		return .ok
	}
	
	#warning("change client-side endpoint, then test")
	func getPublicUserInfo(_ req: Request) throws -> User.PublicInfo {
		let user = try req.auth.require(User.self)
		return user.publicInfo
	}
    
	#warning("test")
	func uploadProfilePic(_ req: Request) async throws -> HTTPStatus {
		let data = try req.content.decode(Data.self)
		let user = try req.auth.require(User.self)
		let userID = try user.requireID()
		let name = userID.uuidString + UUID().uuidString + ".jpg"
		let path = req.application.directory.workingDirectory + imageFolder + name
		
		try await req.fileio.writeFile(.init(data: data), at: path)
		user.profilePic = name
		try await user.save(on: req.db)
		return .ok
	}
}
