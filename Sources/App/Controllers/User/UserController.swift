import Vapor
import Fluent

struct UserController: RouteCollection {
	
	let imageFolder = "ProfilePictures/"
	
	// Verfication code can be used for otp login, first time activation, changing new password, or changing contact info. For the first two purposes, no extra info is needed. So the extra info for last 2 are optional.
	struct VerificationCodeContent: Decodable {
		let credential: String
		let code: String
		let newPassword: String?
		let newContact: String?
		
		init(credential: String, code: String, newPassword: String? = nil, newContact: String? = nil) {
			self.credential = credential
			self.code = code
			self.newPassword = newPassword
			self.newContact = newContact
		}
	}
	
	func boot(routes: RoutesBuilder) throws {
		let publicUsersAPI = routes.grouped("api", "user")
		publicUsersAPI.post("register", use: register)
		// We only send code to existing or registering users, in other words, users have to be stored in database first to request a code. How we find the user from db varies: for otpLogin and resetPassword, it can be a username, an email or phone number cause users won't be able to know their uuid. For changing contact and first time activation, we can use their id coz they have to be logged in to do that.
		publicUsersAPI.post("sendcode", use: sendCode)
		publicUsersAPI.post("code", use: verifyCode)
		publicUsersAPI.post("otplogin", use: loginViaOTP)
		publicUsersAPI.post("resetpw", use: resetPassword)

		let protectedUsersAPI = publicUsersAPI.grouped(User.authenticator(), Token.authenticator())
		protectedUsersAPI.post("login", use: loginViaCredentials)
		protectedUsersAPI.post("logout", use: logout)
		protectedUsersAPI.post("activate", use: activate)
		protectedUsersAPI.post("newcontact", use: requestCodeForNewContact)
		protectedUsersAPI.post("updatecontact", use: updateContact)
		
		let tokenAuthGroup = publicUsersAPI.grouped(Token.authenticator(), User.guardMiddleware())
		tokenAuthGroup.get("public-info", use: getPublicUserInfo)
		tokenAuthGroup.on(.POST, "profile-pic", body: .collect(maxSize: "10mb") , use: uploadProfilePic)
		
		func sendCode(_ req: Request) async throws -> HTTPStatus {
			let credential = try req.content.decode(String.self)
			let user = try await Self.findUser(credential: credential, req: req)
			
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
			try await Self.queueDeleteVerificationCode(req, user: user, code: code)
			return .ok
		}
		
		// Only used for client to decide if it should navigate user to next UI
		func verifyCode(_ req: Request) async throws -> Bool {
			let _ = try await Self.verifyCode(req)
			return true
		}
		
		func register(_ req: Request) async throws -> HTTPStatus {
			let input = try req.content.decode(User.RegisterInput.self)
			let user = try await input.generateUser(req: req)
			let code = try VerificationCode(user: user)
			user.verificationCode = code
			try await user.create(on: req.db)
			
			let recipient = input.contactInfo
			try Self.sendMessage(to: recipient, user: user, subject: "\(serviceName)账号注册验证码", template: .verificationCode, placeHolders: [code.value], client: req.client)
			try await Self.queueDeleteVerificationCode(req, user: user, code: code)
			try await Self.queueDeleteUser(req, user: user)
			
			return .created
		}
		
		// For first time activation after registration
		func activate(_ req: Request) async throws -> HTTPStatus {
			let user = try await Self.verifyCode(req)
			user.verificationCode = nil
			user.verified = true
			try await user.save(on: req.db)
			return .ok
		}
		
		// Basic username/password login, support replacing username by email or phone number.
		func loginViaCredentials(_ req: Request) async throws -> Token {
			let user: User
			
			do {
				// When req.auth.require() fails, default error message is not so user friendly, so we throw authentication error instead.
				user = try req.auth.require(User.self)
			} catch {
				throw AuthenticationError.invalidLoginNameOrPassword
			}
			
			return try await Self.login(req, user: user)
		}
		
		func loginViaOTP(_ req: Request) async throws -> Token {
			let user = try await Self.verifyCode(req)
			user.verificationCode = nil
			try await user.save(on: req.db)
			return try await Self.login(req, user: user)
		}
		
		func resetPassword(_ req: Request) async throws -> HTTPStatus {
			let user = try await Self.verifyCode(req)
			let content = try req.content.decode(VerificationCodeContent.self)
			guard let newPassword = content.newPassword else { throw Abort(.badRequest) }
			
			guard passwordLength.contains(newPassword.count) else {
				throw RegistrationError.passwordLengthError
			}
			
			let hashedPassword = try Bcrypt.hash(newPassword)
			user.password = hashedPassword
			user.verificationCode = nil
			try await user.save(on: req.db)
			return .ok
		}
		
		func logout(_ req: Request) async throws -> HTTPStatus {
			let userID = try req.auth.require(User.self).requireID()
			try await Token.invalidateAll(userID: userID, req: req)
			req.auth.logout(User.self)
			return .ok
		}
		
		// Change existing contact method to a new address. This is a 2 step process: first we need to send verification code to an address has't been bound to a user, so we need user's credential and the new contact info they provided.
		func requestCodeForNewContact(_ req: Request) async throws -> HTTPStatus {
			guard let user = req.auth.get(User.self) else { return .unauthorized }
			
			let contact = try req.content.decode(String.self)
			
			let code = try VerificationCode(user: user)
			user.verificationCode = code
			
			try Self.sendMessage(to: contact, user: user, subject: "\(serviceName)更换联系方式验证码", template: .verificationCode, placeHolders: [code.value], client: req.client)
			// Save the code in db only when message is sent.
			try await user.save(on: req.db)
			
			// Queue the job to remove code later.
			try await Self.queueDeleteVerificationCode(req, user: user, code: code)
			return .ok
		}
		
		// Second step of changing an existing contact is to verify the code, then decode new contact string from request.content, update user's info in db
		func updateContact(_ req: Request) async throws -> HTTPStatus {
			let user = try await Self.verifyCode(req)
			let codeContent = try req.content.decode(VerificationCodeContent.self)
			guard let newContact = codeContent.newContact else { throw Abort(.badRequest) }
			let method = try User.RegisterInput.generateContactMethod(contactInfo: newContact)
			
			switch method {
				case .email:
					user.email = newContact
				case .phone:
					user.phone = newContact
			}
			user.verificationCode = nil
			try await user.save(on: req.db)
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
}

// Functions in this extension shouldn't be called in boot()
extension UserController {
	static func findUser(credential: String, req: Request) async throws -> User {
		guard let user = try await User.query(on: req.db).group(.or, { group in
			if let id = UUID(uuidString: credential) {
				group.filter(\.$id == id)
			}
			group.filter(\.$username == credential)
				.filter(\.$email == credential)
				.filter(\.$phone == credential)
		}).first() else {
			throw AuthenticationError.userNotFound
		}
		return user
	}
	// Marked as private so this func can only be called inside this controlle itself. When calling, make sure don't return the user directly from this function. Sensitive info like password is there too.
	private static func verifyCode(_ req: Request) async throws -> User {
		let codeContent = try req.content.decode(VerificationCodeContent.self)
		let user = try await Self.findUser(credential: codeContent.credential, req: req)
		
		if codeContent.code != user.verificationCode?.value {
			throw AuthenticationError.invalidVerificationCode
		}
		return user
	}
	
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
