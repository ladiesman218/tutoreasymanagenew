import Vapor

enum RegistrationError: Error {
	case passwordsDontMatch
	case emailAlreadyExists
	case usernameAlreadyExists
	case passwordLengthError
	case usernameLengthError
	case invalidEmail
	case invalidUsername
	case invalidDate
}

extension RegistrationError: DebuggableError, AbortError {
	var status: HTTPResponseStatus { return .badRequest }
	
	var reason: String {
		switch self {
		case .passwordsDontMatch:
			return "请确认两次输入的密码完全一致"
		case .emailAlreadyExists:
			return "邮箱地址被占用"
		case .usernameAlreadyExists:
			return "用户名被占用"
		case .passwordLengthError:
			return "密码长度应介于\(passwordLength.lowerBound.description) 到 \((passwordLength.upperBound - 1).description)个字符之间"
		case .usernameLengthError:
			return "用户名应长度应介于\(userNameLength.lowerBound.description) 到 \((userNameLength.upperBound - 1).description)个字符之间"
		case .invalidEmail:
			return "无效邮箱地址"
		case .invalidUsername:
			return "无效用户名"
		case .invalidDate:
			return "无效日期"
		}
	}
	
	var identifier: String {
		switch self {
		case .passwordsDontMatch:
			return "passwords_dont_match"
		case .emailAlreadyExists:
			return "email_already_exists"
		case .usernameAlreadyExists:
			return "username_already_exists"
		case .passwordLengthError:
			return "password_length_error"
		case .usernameLengthError:
			return "username_length_error"
		case .invalidEmail:
			return "invalid_email"
		case .invalidUsername:
			return "invalid_username"
		case .invalidDate:
			return "invalid_date"
		}
	}
}

