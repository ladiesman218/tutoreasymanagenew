import Vapor
import Fluent

final class AdminUser: Model, Content {
	
	enum AdminType: String, Codable {
		case shopOwner, employee
	}
	
	static let schema = "admins"
	
	struct FieldKeys {
		static let email = FieldKey(stringLiteral: "email")
		static let username = FieldKey(stringLiteral: "username")
		static let password = FieldKey(stringLiteral: "password")
		static let isAccepted = FieldKey(stringLiteral: "is_accepted")
		static let adminType = FieldKey(stringLiteral: "admin_type")
		static let registerTime = FieldKey(stringLiteral: "register_time")
		static let lastLoginTime = FieldKey(stringLiteral: "last_login_time")
	}
	
	@ID var id: UUID?
	@Field(key: FieldKeys.email) var email: String
	@Field(key: FieldKeys.username) var username: String
	@Field(key: FieldKeys.password) var password: String
	@Field(key: FieldKeys.isAccepted) var isAccepted: Bool
	@Enum(key: FieldKeys.adminType) var type: AdminType
	@Timestamp(key: FieldKeys.registerTime, on: .create) var registerTime: Date?
	@Timestamp(key: FieldKeys.lastLoginTime, on: .none) var lastLoginTime: Date?
	
	init() {}
	
	init(id: AdminUser.IDValue? = nil, email: String, username: String, password: String, isAccepted: Bool = false, type: AdminType = .employee) {
		self.id = id
		self.email = email
		self.username = username
		self.password = password
		self.isAccepted = isAccepted
		self.type = type
	}
	
}

// Sessions are for using in browsers
extension AdminUser: ModelSessionAuthenticatable {}

extension AdminUser {
	struct RegisterInput: Content {
		
		let email: String
		let username: String
		let password1: String
		let password2: String
		
		func validate(errors: inout [DebuggableError]) {
			if (email.range(of: emailRegex, options: .regularExpression) == nil) {
				errors.append(RegistrationError.invalidEmail)
			}
			
			if username.rangeOfCharacter(from: nonAlphanumerics) != nil {
				errors.append(RegistrationError.invalidUsername)
			}
			
			if !userNameLength.contains(username.count) {
				errors.append(RegistrationError.usernameLengthError)
			}
			
			if password1 != password2 {
				errors.append(RegistrationError.passwordsDontMatch)
			}
			
			if !passwordLength.contains(password1.count) || !passwordLength.contains(password2.count) {
				errors.append(RegistrationError.passwordLengthError)
			}
		}
	}
	
	struct LoginInput: Decodable {
		let loginName: String
		let password: String
	}
}

//extension AdminUser.LoginInput: Validatable {
//  static func validations(_ validations: inout Validations) {
//    validations.add("loginName", as: String.self, is: .email || (.alphanumeric && .count(userNameLength)))
//    validations.add("password", as: String.self, is: .count(passwordLength))
//  }
//}



