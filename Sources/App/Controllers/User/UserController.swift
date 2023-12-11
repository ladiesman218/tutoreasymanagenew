import Vapor
import Fluent

struct UserController: RouteCollection {
	
	let imageFolder = "ProfilePictures/"
	
	func boot(routes: RoutesBuilder) throws {
		let publicUsersAPI = routes.grouped("api", "user")
		publicUsersAPI.post("register", use: register)
		publicUsersAPI.get("activate", ":id", ":code", use: activate)
		
		let protectedUsersAPI = publicUsersAPI.grouped(User.authenticator(), Token.authenticator())
		protectedUsersAPI.post("login", use: login)
		protectedUsersAPI.post("logout", use: logout)
		protectedUsersAPI.get("validate", use: validateToken)
		
		let tokenAuthGroup = publicUsersAPI.grouped(Token.authenticator(), User.guardMiddleware())
		tokenAuthGroup.get("public-info", use: getPublicUserInfo)
		tokenAuthGroup.on(.POST, "profile-pic", body: .collect(maxSize: "10mb") , use: uploadProfilePic)
	}
	
	func register(_ req: Request) async throws -> HTTPStatus {
		let input = try req.content.decode(User.RegisterInput.self)
		let user = try await input.generateUser(req: req)
		try await user.create(on: req.db)
		try await sendVerificationCode(req, userID: user.requireID())
		try await Self.queueDeleteUser(req, user: user)
		
		return .created
	}
	
	func activate(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.verifyCode(req)
		
		user.verified = true
		try await user.save(on: req.db)
		return .ok
	}
	
	func login(_ req: Request) async throws -> Token {
		let user: User
		
		do {
			user = try req.auth.require(User.self)
		} catch {
			throw AuthenticationError.invalidLoginNameOrPassword
		}
		let userID = try user.requireID()
		async let invalidaOldTokens: () = Token.invalidateAll(userID: userID, req: req)
		async let updateLoginTime: () = updateLoginTime(req, user: user)
		let token = Token.generate(for: userID)
		
		try await invalidaOldTokens
		try await token.save(on: req.db)
		try await updateLoginTime
		return token
	}
	
	func logout(_ req: Request) async throws -> HTTPStatus {
		let userID = try req.auth.require(User.self).requireID()
		try await Token.invalidateAll(userID: userID, req: req)
		req.auth.logout(User.self)
		return .ok
	}
	
	func validateToken(_ req: Request) -> Bool {
		let token: Token? = try? req.auth.require(Token.self)
		return token != nil
	}
	
	func getPublicUserInfo(_ req: Request) async throws -> User.PublicInfo {
		let user = try req.auth.require(User.self)
		try await updateLoginTime(req, user: user)
		return user.publicInfo
	}
	
	func updateLoginTime(_ req: Request, user: User) async throws {
		user.lastLoginTime = Date.now
		try await user.save(on: req.db)
	}
	
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
	
	func sendVerificationCode(_ req: Request, userID: User.IDValue) async throws {
		// Make sure user has been stored in db
		guard let user = try await User.find(userID, on: req.db) else {
			throw AuthenticationError.userNotFound
		}
		// If user has requested a code in less than 1 minute ago
		if let lastTime = user.verificationCode?.genTime,
		   Date(timeInterval: 60, since: lastTime) > Date.now {
			throw AuthenticationError.frequentCodeRequest
		}
		
		// Generate code for user, then store it in db.
		let code = User.VerificationCode()
		user.verificationCode = code
		try await user.save(on: req.db)

		// Send the code via primary contact method
		switch user.primaryContact {
			case .email:
				guard let email = Email(sender: .noreply, to: [user], subject: "师轻松验证码", template: .verificationCode, placeHolders: [code.value], client: req.client) else {
					return
				}
				email.send(client: req.client)
			case .phone:
				guard let sms = SMS(recipient: user, template: .verificationCode, placeHolders: [code.value], client: req.client) else {
					return
				}
				sms.send(client: req.client)
		}

		// Queue the job to remove code later.
		try? await Self.queueDeleteVerificationCode(req, user: user, code: code)
	}
}

// Functions in extension shouldn't be called in boot()
extension UserController {
	// This function only returns the user if everything works as expected, or throws if anything goes wrong. Code verification could do more than just verify the user for the first time.
	static func verifyCode(_ req: Request) async throws -> User {
		guard let idString = req.parameters.get("id"),
			  let userID = UUID(idString),
			  let codeValue = req.parameters.get("code"),
			  !codeValue.isEmpty else {
			throw Abort(.badRequest)
		}
		
		guard let user = try await User.find(userID, on: req.db) else {
			throw AuthenticationError.userNotFound
		}
		
		guard codeValue == user.verificationCode?.value else {
			throw AuthenticationError.invalidVerificationCode
		}
		// Here means both codes matched, we can remove it
		user.verificationCode = nil
		try await user.save(on: req.db)
		return user
	}
	
	static func queueDeleteVerificationCode(_ req: Request, user: User, code: User.VerificationCode) async throws {
		// Delay the job after 7mins
		let futureTime = Date(timeInterval: 60 * 7, since: code.genTime)
		try await req.queue.dispatch(UserJobs.self, UserExecution(execution: .deleteCode, userID: user.requireID(), code: code), delayUntil: futureTime)
	}
	
	static func queueDeleteUser(_ req: Request, user: User) async throws {
		// Delay the job after 1 month
		let futureDate = Date(timeIntervalSinceNow: 30 * 24 * 60 * 60)
		try await req.queue.dispatch(UserJobs.self, UserExecution(execution: .deleteUser, userID: user.requireID()), delayUntil: futureDate)
	}
}
