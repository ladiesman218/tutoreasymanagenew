import Vapor
import Fluent

struct ProfilePicData: Content {
    var image: Data
}


final class User: Model, Content {
	
	static let schema = "users"
	
	struct FieldKeys {
		static let email: FieldKey = .string("email")
		static let username: FieldKey = .string("username")
		static let firstName: FieldKey = .string("first_name")
		static let lastName: FieldKey = .string("last_name")
		static let password: FieldKey = .string("password")
		static let registerTime: FieldKey = .string("register_time")
		static let lastLoginTime: FieldKey = .string("last_login_time")
        static let profilePic: FieldKey = .string("profile_pic")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.email) var email: String
	@Field(key: FieldKeys.username) var username: String
	@OptionalField(key: FieldKeys.firstName ) var firstName: String?
	@OptionalField(key: FieldKeys.lastName) var lastName: String?
	@Field(key: FieldKeys.password) var password: String
	@Timestamp(key: FieldKeys.registerTime, on: .create) var registerTime: Date?
	@Timestamp(key: FieldKeys.lastLoginTime, on: .none) var lastLoginTime: Date?
    @OptionalField(key: FieldKeys.profilePic) var profilePic: String?
	@Children(for: \Order.$user) var orders: [Order]
	
	init() {}
	
    init(id: User.IDValue? = nil, email: String, username: String, firstName: String?, lastName: String?, password: String, profilePic: String?) {
		self.id = id
		self.email = email
		self.username = username
		self.firstName = firstName
		self.lastName = lastName
		self.password = password
        self.profilePic = profilePic
	}
}

extension User: ModelAuthenticatable {
	static let usernameKey = \User.$username
	static let passwordHashKey = \User.$password

	func verify(password: String) throws -> Bool {
		try Bcrypt.verify(password, created: self.password)
	}
}

extension User {
	
	struct RegisterInput: Decodable {
		let email: String
		let username: String
		var firstName: String?
		var lastName: String?
		let password1: String
		let password2: String
		
		func validate(errors: inout [DebuggableError], req: Request) async throws {
			async let foundEmail = User.query(on: req.db).filter(\.$email == email).first()
			async let foundUsername = User.query(on: req.db).filter(\.$username == username).first()

			if email.range(of: emailRegex, options: .regularExpression) == nil {
				errors.append(RegistrationError.invalidEmail)
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
//			let startTime = Date.now
			if try await foundEmail != nil {
				errors.append(RegistrationError.emailAlreadyExists)
			}
			if try await foundUsername != nil {
				errors.append(RegistrationError.usernameAlreadyExists)
			}
//			print(Date.now.timeIntervalSince(startTime))
		}
	}
}

extension User {
	
	struct PublicInfo: Content {
		let id: UUID
		let email: String
		let username: String
		var firstName: String?
		var lastName: String?
		let registerTime: Date?
		let lastLoginTime: Date?
        let profilePic: String?
	}
	
	var publicInfo: PublicInfo {
		.init(id: id!, email: self.email, username: self.username, firstName: self.firstName, lastName: self.lastName, registerTime: self.registerTime, lastLoginTime: self.lastLoginTime, profilePic: self.profilePic)
	}
}

extension User: Equatable {
	static func == (lhs: User, rhs: User) -> Bool {
		return lhs.id == rhs.id
	}
}
