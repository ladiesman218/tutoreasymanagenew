import Vapor
import Fluent


struct AdminController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let admin = routes.grouped("api", "admin")
        admin.post("register", use: register)
        admin.post("login", use: login)
        // Either group logout with AdminUser.sessionAuthenticator, or call req.session.unauthenticate(admin) manually in logout function, otherwise API won't work but web will...
        admin.post("logout", use: logout)
    }
    
	func register(_ req: Request) async throws -> AdminUser {
		var errors = [DebuggableError]()
		let input: AdminUser.RegisterInput
		input = try req.content.decode(AdminUser.RegisterInput.self)
		input.validate(errors: &errors)
		
		// email and username validation. Multiple async let command runs simultaneously, so here query for existing email and username, along with password hash down below, won't take 3 times of time each task should be taken.
		async let foundEmail = AdminUser.query(on: req.db).filter(\.$email == input.email).first()
		async let foundUsername = AdminUser.query(on: req.db).filter(\.$username == input.username).first()
		if try await foundEmail != nil { errors.append(RegistrationError.emailAlreadyExists) }
		if try await foundUsername != nil { errors.append(RegistrationError.usernameAlreadyExists) }
		
		guard errors.isEmpty else { throw errors.abort }
		
		async let passwordHash = req.password.async.hash(input.password1)
		let admin = try await AdminUser(email: input.email, username: input.username, password: passwordHash)
		
		// create command throws, so if the creation fails, the function throws thus won't be returning the admin user
		try await admin.create(on: req.db)
		return admin
	}
	
	func login(_ req: Request) async throws -> Response {
		let input = try req.content.decode(AdminUser.LoginInput.self)
		
        // Make sure there is an admin account with either the given username or email address
		guard let foundAdmin = try await AdminUser.query(on: req.db).group(.or, { group in
			group.filter(\.$username == input.loginName)
			group.filter(\.$email == input.loginName)
		}).first() else {
			throw AuthenticationError.userNotFound
		}
		
		// Make sure the given account is approved by the owner
		guard foundAdmin.isAccepted else { throw AuthenticationError.adminNotApproved }
		// Make sure the password and loginName matches
		guard try req.password.verify(input.password, created: foundAdmin.password) else {
			throw AuthenticationError.invalidLoginNameOrPassword
		}
		
		// Invalidate all sessions for the given admin acount first
		try await foundAdmin.unauthenticateAllSessions(id: foundAdmin.id!, req: req, sessionDataKey: "_AdminUserSession")
//		let _ = foundAdmin.unauthenticateAllSessions(id: foundAdmin.id!, req: req, sessionDataKey: "_AdminUserSession")
		req.auth.login(foundAdmin)
		req.session.authenticate(foundAdmin)
		foundAdmin.lastLoginTime = Date()
		try await foundAdmin.save(on: req.db)
		return Response()
	}
    
    func logout(req: Request) -> HTTPStatus {
        req.auth.logout(AdminUser.self)
        req.session.unauthenticate(AdminUser.self)
        return HTTPStatus.ok
    }
    
    
}

