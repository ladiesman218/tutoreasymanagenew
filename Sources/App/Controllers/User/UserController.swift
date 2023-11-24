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
		var errors: [DebuggableError] = []
		let input = try req.content.decode(User.RegisterInput.self)
		try await input.validate(errors: &errors, req: req)
		guard errors.isEmpty else { throw errors.abort }
		let hashedPassword = try Bcrypt.hash(input.password1)
		let user = User(email: input.email, username: input.username, firstName: input.firstName, lastName: input.lastName, password: hashedPassword, profilePic: nil)
		try await user.create(on: req.db)
		try await sendVerificationCode(req, userID: user.requireID())
		try await Self.queueDeleteUser(req, user: user)
		
		return .created
	}
	
	func activate(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.verifyCode(req)
		
		user.verified = true
		user.verificationCode = nil
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
		// Make sure use has been stored in db
		guard let user = try await User.find(userID, on: req.db) else {
			throw AuthenticationError.userNotFound
		}
		// If user has requested a code in less than 1 minute ago
		if let lastTime = user.verificationCode?.genTime,
		   Date(timeInterval: 60, since: lastTime) > Date.now {
			throw AuthenticationError.frequentCodeRequest
		}
		
		let code = User.VerificationCode()
		user.verificationCode = code
		
		let userEmail = Email.Account(name: user.username, email: user.email)
		let message = try Email.Body.generate(placeHolders: [code.value], template: Email.Body.verificationCodeTemplate, client: req.client)
		let email = Email(sender: .noreply, recipients: [userEmail], subject: "师轻松验证码", emailMessage: message)
		
		try await user.save(on: req.db)
		email.send(client: req.client)
		
		// Queue the job to remove code later.
		try? await Self.queueDeleteVerificationCode(req, user: user, code: code)
	}
}

// Functions in extension shouldn't be called in boot()
extension UserController {
	// This function only returns the user if everything works as expected, or throws if anything wrong.
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
		// Don't remove the code since user may make a typo and try again.
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
