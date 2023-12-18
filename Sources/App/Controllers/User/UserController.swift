import Vapor
import Fluent

struct UserController: RouteCollection {
	
	let imageFolder = "ProfilePictures/"
	
	func boot(routes: RoutesBuilder) throws {
		let publicUsersAPI = routes.grouped("api", "user")
		publicUsersAPI.post("register", use: register)
		// sendCode() use ":credential" to guard a user is found by the given credential, it can be an username, an email address or phone number. So this should be called for normal usage: otplogin or reset password, not for changing a new contact address coz in that senario if we pass in the new address as ":credential", it won't be able to find an associated user since user and new address haven't been bound yet.
		publicUsersAPI.post("sendcode", ":credential", use: sendCode)
		// Following routes are public, but they need userID and verification code to work, so these should be safe.
		publicUsersAPI.post("otplogin", ":id", ":code", use: loginViaOTP)
		publicUsersAPI.post("resetpw", ":id", ":code", use: resetPassword)

		let protectedUsersAPI = publicUsersAPI.grouped(User.authenticator(), Token.authenticator())
		protectedUsersAPI.post("login", use: loginViaCredentials)
		protectedUsersAPI.post("logout", use: logout)
		protectedUsersAPI.post("activate", ":id", ":code", use: activate)
		// Change existing contact method to a new address. This is a 2 step process: first we need to send verification code to an address has't been bound to a user, so we need user id to manually bind them together.
		protectedUsersAPI.post("newcontact", ":id", ":contact", use: requestCodeForNewContact)
		// Second step of changing an existing contact is to verify the code, then decode new contact string from request.content, update user's info in db
		protectedUsersAPI.post("updatecontact", ":id", ":code", use: updateContact)
		
		let tokenAuthGroup = publicUsersAPI.grouped(Token.authenticator(), User.guardMiddleware())
		tokenAuthGroup.get("public-info", use: getPublicUserInfo)
		tokenAuthGroup.on(.POST, "profile-pic", body: .collect(maxSize: "10mb") , use: uploadProfilePic)
	}
	
	func register(_ req: Request) async throws -> HTTPStatus {
		let input = try req.content.decode(User.RegisterInput.self)
		let user = try await input.generateUser(req: req)
		let code = try VerificationCode(user: user)
		user.verificationCode = code
		try await user.create(on: req.db)
		
		let recipient = input.contactInfo
		try Self.sendMessage(to: recipient, user: user, subject: "\(serviceName)验证码", template: .verificationCode, placeHolders: [code.value], client: req.client)
		try await Self.queueDeleteUser(req, user: user)
		
		return .created
	}
	
	func sendCode(_ req: Request) async throws -> HTTPStatus {
		guard let credential = req.parameters.get("credential") else { throw Abort(.badRequest) }
		
		guard let user = try await User.query(on: req.db).group(.or, { group in
			group.filter(\.$email == credential)
				.filter(\.$phone == credential)
				.filter(\.$username == credential)
		}).first() else {
			throw AuthenticationError.userNotFound
		}
		
		let code = try VerificationCode(user: user)
		user.verificationCode = code
		
		let address: String
		if user.username == credential {
			switch user.primaryContact {
				case .email:
					address = user.email!
				case .phone:
					address = user.phone!
			}
		} else {
			address = credential
		}
		
		try Self.sendMessage(to: address, user: user, subject: "\(serviceName)验证码", template: .verificationCode, placeHolders: [code.value], client: req.client)
		
		// Save the code in db only when message is sent.
		try await user.save(on: req.db)

		// Queue the job to remove code later.
		try? await Self.queueDeleteVerificationCode(req, user: user, code: code)
		return .ok
	}
	
	func requestCodeForNewContact(_ req: Request) async throws -> HTTPStatus {
		guard let contact = req.parameters.get("contact"),
			  let idString = req.parameters.get("id"),
			  let id = UUID(idString) else {
			throw Abort(.badRequest)
		}
		
		guard let user = try await User.find(id, on: req.db) else { throw AuthenticationError.userNotFound }
		
		let code = try VerificationCode(user: user)
		user.verificationCode = code
		
		try Self.sendMessage(to: contact, user: user, subject: "\(serviceName)验证码", template: .verificationCode, placeHolders: [code.value], client: req.client)
		// Save the code in db only when message is sent.
		try await user.save(on: req.db)

		// Queue the job to remove code later.
		try? await Self.queueDeleteVerificationCode(req, user: user, code: code)
		return .ok
	}
	
	func updateContact(_ req: Request) async throws -> HTTPStatus {
		let user = try await Self.verifyCode(req)
		let string = try req.content.decode(String.self)
		let method = try User.RegisterInput.generateContactMethod(contactInfo: string)
		
		switch method {
			case .email:
				user.email = string
			case .phone:
				user.phone = string
		}
		try await user.save(on: req.db)
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
		let passwordArray = try req.content.decode([String].self)
		guard passwordArray.count == 2 else {
			throw Abort(.badRequest)
		}
		
		let password1 = passwordArray[0], password2 = passwordArray[1]
		
		guard password1 == password2 else {
			throw RegistrationError.passwordsDontMatch
		}
		guard passwordLength.contains(password1.count) else {
			throw RegistrationError.passwordLengthError
		}
		
		let hashedPassword = try Bcrypt.hash(password1)
		user.password = hashedPassword
		try await user.save(on: req.db)
		return .ok
	}

	// Via one time password sent by email or SMS
	func loginViaOTP(_ req: Request) async throws -> Token {
		let user = try await Self.verifyCode(req)
		return try await Self.login(req, user: user)
	}
	
	// Basic username/password login, support replacing username by email or phone number.
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
	// subject can be nil if recipient is a phone number.
	static func sendMessage(to recipient: String, user: User, subject: String? = nil, template: MessageBody.Template, placeHolders: [String], client: Client) throws {
		// Make sure user is already stored in db
		guard let _ = try? user.requireID() else {
			throw AuthenticationError.userNotFound
		}
		
		let method = try User.RegisterInput.generateContactMethod(contactInfo: recipient)
		
		switch method {
			case .email:
				guard let subject = subject else {
					let error = MessageError.invalidEmailSubject
					Email.alertAdmin(error: error, client: client)
					throw error
				}
				
				// If we get here, means generateContactMethod() didn't throw, so we can safely force try! to generate an account
				let account = try! Email.Account(name: user.username, email: recipient)
				let message = try MessageBody(template: template, placeHolders: placeHolders, client: client)
				let email = try Email(to: [account], subject: subject, message: message, client: client)
				email.send(client: client)
				
			case .phone:
				let message = try MessageBody(template: template, placeHolders: placeHolders, removeHTML: true, client: client)
				let sms = try SMS(recipient: recipient, message: message, client: client)
				sms.send(client: client)
		}
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
	
	static func queueDeleteVerificationCode(_ req: Request, user: User, code: VerificationCode) async throws {
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
