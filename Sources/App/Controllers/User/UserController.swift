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
		tokenAuthGroup.get("token", "user-public", use: getPublicUserFromToken)
        tokenAuthGroup.on(.POST, "profile-pic", body: .collect(maxSize: "10mb") , use: uploadProfilePic)
	}
	
	func register(_ req: Request) throws -> EventLoopFuture<Response> {
		var errors: [DebuggableError] = []
		
		let input: User.RegisterInput
		
		input = try req.content.decode(User.RegisterInput.self)
		 
		input.validate(errors: &errors)
		
		// Validate database contraints
		let queryEmail = User.query(on: req.db).filter(\.$email == input.email).first().map { foundEmail in
			if foundEmail != nil { errors.append(RegistrationError.emailAlreadyExists) }
		}
		let queryUsername = User.query(on: req.db).filter(\.$username == input.username).first().map { foundUsername in
			if foundUsername != nil { errors.append(RegistrationError.usernameAlreadyExists) }
		}

		var hashedPassword = ""
        return queryEmail.and(queryUsername).guard({ _ in
            errors.isEmpty
        }, else: errors.abort).flatMapThrowing { _ in
			hashedPassword = try Bcrypt.hash(input.password1)
		}.flatMap { _ in
            let user = User(email: input.email, username: input.username, firstName: input.firstName, lastName: input.lastName, password: hashedPassword, profilePic: nil)
			return user.save(on: req.db).transform(to: HTTPStatus.created).encodeResponse(for: req)
		}
	}
	
	func login(_ req: Request) -> EventLoopFuture<Token> {
		let user: User
		
		do {
			user = try req.auth.require(User.self)
		} catch {
			return req.eventLoop.future(error: AuthenticationError.invalidLoginNameOrPassword)
		}
		
		let userID = user.id!
		let token = Token.generate(for: userID)
		
		return Token.invalidateAll(userID: userID, req: req).flatMap { _ in
			return token.save(on: req.db).transform(to: token)
		}
	}
	
	func logout(req: Request) -> EventLoopFuture<HTTPStatus> {
		// Get the user's ID, then invalidate its tokens, then logout
		guard let userID = try? req.auth.require(User.self).requireID() else {
			return req.eventLoop.future(.badRequest)
		}
		
		return Token.invalidateAll(userID: userID, req: req).map { _ in
			req.auth.logout(User.self)
			return HTTPStatus.ok
		}
	}

	func getPublicUserFromToken(req: Request) throws -> User.PublicInfo {
		let user: User = try req.auth.require(User.self)
		
		return User.PublicInfo(id: user.id!, email: user.email, username: user.username, firstName: user.firstName, lastName: user.lastName, registerTime: user.registerTime, lastLoginTime: user.lastLoginTime, profilePic: user.profilePic)
	}
    
    func uploadProfilePic(req: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let data = try req.content.decode(Data.self)
        guard let user = req.auth.get(User.self) else { throw Abort(.notFound) }
        let userID = try user.requireID()
        let name = userID.uuidString + UUID().uuidString + ".jpg"
        
//        let dt = ByteBuffer(data: data.image)
        
        let path = req.application.directory.workingDirectory + imageFolder + name
        return req.fileio.writeFile(.init(data: data), at: path).flatMap { _ in
            user.profilePic = name
            return user.save(on: req.db).transform(to: .ok)
        }
    }
    
}
