import Vapor
import Fluent

struct UserController: RouteCollection {
	
	let imageFolder = "ProfilePictures/"
	
	func boot(routes: RoutesBuilder) throws {
		let publicUsersAPI = routes.grouped("api", "user")
		publicUsersAPI.post("register", use: register)
		// Following routes are public, but they need userID and verification code to work, so these should be safe
		publicUsersAPI.get("activate", ":id", ":code", use: activate)
		publicUsersAPI.post("otplogin", ":id", ":code", use: loginViaOTP)
		publicUsersAPI.post("setContact", ":id", ":code", use: changeContactInfo)
		publicUsersAPI.post("resetpw", ":id", ":code", use: resetPassword)
		
		publicUsersAPI.post("newContact", ":contact", use: requestNewContact)

		// User can ask for a verification code by providing their login credential, it can be an id, email, or phone number
		publicUsersAPI.post("sendcode", ":credential", use: sendCode)
		
		let protectedUsersAPI = publicUsersAPI.grouped(User.authenticator(), Token.authenticator())
		protectedUsersAPI.post("login", use: loginViaCredentials)
		protectedUsersAPI.post("logout", use: logout)
		protectedUsersAPI.post("activate", use: activate)
		
		let tokenAuthGroup = publicUsersAPI.grouped(Token.authenticator(), User.guardMiddleware())
		tokenAuthGroup.get("public-info", use: getPublicUserInfo)
		tokenAuthGroup.on(.POST, "profile-pic", body: .collect(maxSize: "10mb") , use: uploadProfilePic)
	}
	
	func register(_ req: Request) async throws -> HTTPStatus {
		let input = try req.content.decode(User.RegisterInput.self)
		let user = try await input.generateUser(req: req)
		try await user.create(on: req.db)
		try await Self.sendVerificationCode(req, credential: user.requireID().uuidString)
		try await Self.queueDeleteUser(req, user: user)
		
		return .created
	}
	
	func sendCode(_ req: Request) async throws -> HTTPStatus {
		guard let credential = req.parameters.get("credential") else {
			throw Abort(.badRequest)
		}

		try await Self.sendVerificationCode(req, credential: credential)
		return .ok
	}
	
	func activate(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.verifyCode(req)
		
		user.verified = true
		try await user.save(on: req.db)
		return .ok
	}
	
	func resetPassword(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.verifyCode(req)
		let newPassword = try req.content.decode(String.self)
		guard !newPassword.isEmpty else {
			throw RegistrationError.passwordLengthError
		}
		let hashedPassword = try Bcrypt.hash(newPassword)
		user.password = hashedPassword
		try await user.save(on: req.db)
		return .ok
	}
	
	func requestNewContact(_ req: Request) async throws -> HTTPStatus{
		guard let contact = req.parameters.get("contact") else {
			throw Abort(.badRequest)
		}
		guard let method = try? User.RegisterInput.generateContactMethod(contactInfo: contact) else {
			throw RegistrationError.invalidContactInfo
		}
//		switch method {
//			case .email:
//				let email
//		}
		return .ok
	}
	
	func changeContactInfo(_ req: Request) async throws -> HTTPStatus {
		#warning("verify the new info actually belongs to the user")
		async let user = try await Self.verifyCode(req)
		
		// Get new contact info from request body, do validation. requestBody should be decoded to something like ["primaryContact": "test@test.com"]
		let requestBody = try req.content.decode(Dictionary<String, String>.self)
		guard requestBody.count == 1, let dict = requestBody.first else { throw Abort(.badRequest) }
		// Decide which type of contact info the new string is, if it's neither an email nor a phone, the function throws
		let newInfo = try User.RegisterInput.generateContactMethod(contactInfo: dict.value)

		// Change primary or secondary contact info to newInfo, base on the key.
		if dict.key == User.FieldKeys.primaryContact.description {
			try await user.primaryContact = newInfo
		} else if dict.key == User.FieldKeys.secondaryContact.description {
			try await user.secondaryContact = newInfo
		} else {
			throw Abort(.badRequest)
		}
		// Change email or phone field in db into new string value, base on newInfo case.
		switch newInfo {
			case .email:
				try await user.email = dict.value
			case .phone:
				try await user.phone = dict.value
		}
		try await user.save(on: req.db)
		return .ok
	}
	
	// Via one time password sent by email or SMS
	func loginViaOTP(_ req: Request) async throws -> Token {
		let user = try await Self.verifyCode(req)
		return try await Self.login(req, user: user)
	}
	
	func loginViaCredentials(_ req: Request) async throws -> Token {
		let user: User
		
		do {
			user = try req.auth.require(User.self)
		} catch {
			throw AuthenticationError.invalidLoginNameOrPassword
		}
		
		return try await Self.login(req, user: user)
	}
	
	func logout(_ req: Request) async throws -> HTTPStatus {
		let userID = try req.auth.require(User.self).requireID()
		try await Token.invalidateAll(userID: userID, req: req)
		req.auth.logout(User.self)
		return .ok
	}
	
	func getPublicUserInfo(_ req: Request) async throws -> User.PublicInfo {
		let user = try req.auth.require(User.self)
		user.updateLoginTime()
		try await user.save(on: req.db)
		return user.publicInfo
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
}

// Functions in extension shouldn't be called in boot()
extension UserController {
	static func sendVerificationCode(_ req: Request, credential: String) async throws {
		guard !credential.isEmpty else {
			throw Abort(.badRequest, reason: "请登录或输入有效账号")
		}
		
		guard let user = try await User.query(on: req.db).group(.or, { group in
			if let id = UUID(uuidString: credential) {
				group.filter(\.$id == id)
			}
			group.filter(\.$username == credential)
			group.filter(\.$email == credential)
			group.filter(\.$phone == credential)
		}).first() else {
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
		
		// Decide whether to send the code via SMS or email, can't use nil coalescing here...
		let method: User.ContactMethod
		// If the passed in credential stands for a contact method value itself, send code via that method
		if let contact = try? User.RegisterInput.generateContactMethod(contactInfo: credential) {
			method = contact
		} else {
			method = user.primaryContact
		}

		switch method {
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
		
	// Code verification could do more than just verify the user for the first time, maybe user is resetting a password, changing a new contact info, or even logging in via onetime code. We will need the user instance for later usage, so this function only returns the user if everything works as expected, or throws if anything goes wrong.
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
	
	// This function invalid old tokens for the given user, updates login time, generate a new token and returns it. But how the user parameter is passed in depends on the caller. In OTP, user is returned by verifyCode() function; in normal credential login, user is get by req.auth.
	static func login(_ req: Request, user: User) async throws -> Token {
		let userID = try user.requireID()
		async let invalidaOldTokens: () = Token.invalidateAll(userID: userID, req: req)
		let token = Token.generate(for: userID)
		try await invalidaOldTokens
		try await token.save(on: req.db)
		
		user.updateLoginTime()
		try await user.save(on: req.db)
		return token
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
