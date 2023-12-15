import Vapor
import Fluent

struct ProfilePicData: Content {
    var image: Data
}


final class User: Model, Content {
	
	static let schema = "users"
	
	// Value is the actual verification code, genTime is used to store timestamp when the code is generated, we use the combination of these 2 to compare if 2 codes are identical.
	struct VerificationCode: Codable, Equatable {
		let value: String
		let genTime: Date
		init() {
			var string = ""
			for _ in 1 ... 6 { string += String(Int.random(in: 1...9)) }
			self.value = string
			self.genTime = Date.now
		}
	}
	
	enum ContactMethod: String, Codable {
		case email
		case phone
	}
	
	struct FieldKeys {
		static let contactMethod: FieldKey = .string("contact_method")
		static let primaryContact: FieldKey = .string("primary_contact")
		static let secondaryContact: FieldKey = .string("secondary_contact")
		static let email: FieldKey = .string("email")
		static let phone: FieldKey = .string("phone")
		static let username: FieldKey = .string("username")
		static let firstName: FieldKey = .string("first_name")
		static let lastName: FieldKey = .string("last_name")
		static let password: FieldKey = .string("password")
		static let registerTime: FieldKey = .string("register_time")
		static let lastLoginTime: FieldKey = .string("last_login_time")
        static let profilePic: FieldKey = .string("profile_pic")
		static let verificationCode: FieldKey = .string("verification_code")
		static let verified: FieldKey = .string("verified")
	}
	
	@ID var id: UUID?
	@Enum(key: FieldKeys.primaryContact) var primaryContact: ContactMethod
	@OptionalEnum(key: FieldKeys.secondaryContact) var secondaryContact: ContactMethod?
	@OptionalField(key: FieldKeys.email) var email: String?
	@OptionalField(key: FieldKeys.phone) var phone: String?
	@Field(key: FieldKeys.username) var username: String
	@OptionalField(key: FieldKeys.firstName) var firstName: String?
	@OptionalField(key: FieldKeys.lastName) var lastName: String?
	@Field(key: FieldKeys.password) var password: String
	@Timestamp(key: FieldKeys.registerTime, on: .create) var registerTime: Date?
	@Timestamp(key: FieldKeys.lastLoginTime, on: .none) var lastLoginTime: Date?
    @OptionalField(key: FieldKeys.profilePic) var profilePic: String?
	@Children(for: \Order.$user) var orders: [Order]
	@OptionalField(key: FieldKeys.verificationCode) var verificationCode: VerificationCode?
	@Field(key: FieldKeys.verified) var verified: Bool
	
	init() {}
	
	init(primaryContact: ContactMethod, secondaryContact: ContactMethod? = nil, email: String? = nil, phone: String? = nil, username: String, firstName: String? = nil, lastName: String? = nil, password: String, profilePic: String? = nil) {
		// 2 values are fixed when creating a new instance, id is always nil and verified is false.
		self.id = nil
		self.primaryContact = primaryContact
		self.secondaryContact = secondaryContact
		self.email = email
		self.phone = phone
		self.username = username
		self.firstName = firstName
		self.lastName = lastName
		self.password = password
        self.profilePic = profilePic
		self.verified = false
	}
}

extension User {
	func updateLoginTime() {
		self.lastLoginTime = Date.now
	}
	
	struct RegisterInput: Decodable {
		let contactInfo: String
		let username: String
		var firstName: String?
		var lastName: String?
		let password1: String
		let password2: String
		
		func validate(errors: inout [DebuggableError], req: Request) async throws {
			async let foundEmail = User.query(on: req.db).filter(\.$email == contactInfo).first()
			async let foundPhoneNumber = User.query(on: req.db).filter(\.$phone == contactInfo).first()
			async let foundUsername = User.query(on: req.db).filter(\.$username == username).first()

			if contactInfo.range(of: emailRegex, options: .regularExpression) == nil &&
				contactInfo.range(of: cnPhoneRegex, options: .regularExpression) == nil {
				errors.append(RegistrationError.invalidContactInfo)
			}
			if !userNameLength.contains(username.count) {
				errors.append(RegistrationError.usernameLengthError)
			}
			if let firstName = firstName, !nameLength.contains(firstName.count) {
				errors.append(GeneralInputError.nameLengthInvalid)
			}
			if let lastName = lastName, !nameLength.contains(lastName.count) {
				errors.append(GeneralInputError.nameLengthInvalid)
			}
			if password1 != password2 {
				errors.append(RegistrationError.passwordsDontMatch)
			}
			if !passwordLength.contains(password1.count) {
				errors.append(RegistrationError.passwordLengthError)
			}
			if try await foundEmail != nil {
				errors.append(RegistrationError.emailAlreadyExists)
			}
			if try await foundPhoneNumber != nil {
				errors.append(RegistrationError.phoneAlreadyExists)
			}
			if try await foundUsername != nil {
				errors.append(RegistrationError.usernameAlreadyExists)
			}
		}
		
		func generateUser(req: Request) async throws -> User {
			var errors = [DebuggableError]()
			try await validate(errors: &errors, req: req)
			guard errors.isEmpty else { throw errors.abort }
			let hashedPassword = try Bcrypt.hash(password1)
			
			let contactMethod = try Self.generateContactMethod(contactInfo: contactInfo)
			
			let user = User(primaryContact: contactMethod, username: username, firstName: firstName, lastName: lastName, password: hashedPassword, profilePic: nil)
			switch contactMethod {
				case .email:
					user.email = contactInfo
				case .phone:
					user.phone = contactInfo
			}
			return user
		}
		
		static func generateContactMethod(contactInfo: String) throws -> ContactMethod {
			if contactInfo.range(of: emailRegex, options: .regularExpression) != nil {
				return .email
			} else if contactInfo.range(of: cnPhoneRegex, options: .regularExpression) != nil {
				return .phone
			} else {
				throw RegistrationError.invalidContactInfo
			}
		}
	}
}

extension User {
	
	struct PublicInfo: Content {
		let id: UUID
		let primaryContact: ContactMethod
		let secondaryContact: ContactMethod?
		let email: String?
		let phone: String?
		let username: String
		var firstName: String?
		var lastName: String?
		let registerTime: Date?
		let lastLoginTime: Date?
        let profilePic: String?
		let verified: Bool
	}
	
	var publicInfo: PublicInfo {
		.init(id: id!, primaryContact: self.primaryContact, secondaryContact: self.secondaryContact, email: self.email, phone: self.phone, username: self.username, firstName: self.firstName, lastName: self.lastName, registerTime: self.registerTime, lastLoginTime: self.lastLoginTime, profilePic: self.profilePic, verified: verified)
	}
}

extension User: Equatable {
	static func == (lhs: User, rhs: User) -> Bool {
		return lhs.id == rhs.id
	}
}

// In order to utilize the request.auth property, User has to conform to ModelAuthenticatable protocol. But the default implementation only allows one field in db to be used as username. Here we wanna use either one from these 3: username, email or phone number. So everything in the following protocol conformance is required and default, except for 1 we've customized: authenticator() function now returns a customized UserAuthenticator instance instead of ModelAuthenticatable's default implementation.
extension User: ModelAuthenticatable {
	static let usernameKey = \User.$username
	static let passwordHashKey = \User.$password
	
	public static func authenticator(
		database: DatabaseID? = nil
	) -> Authenticator {
		UserAuthenticator()
	}
	func verify(password: String) throws -> Bool {
		try Bcrypt.verify(password, created: self.password)
	}
}

struct UserAuthenticator: BasicAuthenticator {
	func authenticate(basic: Vapor.BasicAuthorization, for request: Vapor.Request) -> EventLoopFuture<Void> {
		User.query(on: request.db).group(.or, { group in
			group.filter(\.$username == basic.username)
			group.filter(\.$email == basic.username)
			group.filter(\.$phone == basic.username)
		})
		.first()
		.flatMapThrowing
		{
			guard let user = $0 else {
				return
			}
			guard try user.verify(password: basic.password) else {
				return
			}
			request.auth.login(user)
		}
	}
}
