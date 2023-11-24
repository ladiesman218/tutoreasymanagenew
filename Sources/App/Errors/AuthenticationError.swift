import Vapor

enum AuthenticationError: Error {
	case invalidLoginNameOrPassword
	case emailIsNotVerified
	case adminNotApproved
	case userNotFound
	case tokenValueError
	case invalidVerificationCode
	case frequentCodeRequest
}

extension AuthenticationError: AbortError, DebuggableError {
	var status: HTTPResponseStatus {
		switch self {
		case .invalidLoginNameOrPassword:
			return .unauthorized
		case .emailIsNotVerified:
			return .unauthorized
		case .adminNotApproved:
			return .unauthorized
		case .userNotFound:
			return .notFound
		case .tokenValueError:
			return .badRequest
		case .invalidVerificationCode:
			return .unauthorized
		case .frequentCodeRequest:
			return .tooManyRequests
		}
	}
	
	var reason: String {
		switch self {
		case .invalidLoginNameOrPassword:
			return "用户名或密码错误"
		case .emailIsNotVerified:
			return "邮箱未验证"
		case .adminNotApproved:
			return "等待所有者审核中"
		case .userNotFound:
			return "未找到用户"
		case .tokenValueError:
			return "令牌错误"
		case .invalidVerificationCode:
			return "验证码无效"
		case .frequentCodeRequest:
			return "频繁验证码请求，请稍后再试"
		}
	}
	
	var identifier: String {
		switch self {
		case .invalidLoginNameOrPassword:
			return "invalid_email_or_password"
		case .emailIsNotVerified:
			return "email_is_not_verified"
		case .adminNotApproved:
			return "admin_not_approved"
		case .userNotFound:
			return "user_not_found"
		case .tokenValueError:
			return "token_value_error"
		case .invalidVerificationCode:
			return "invalid_verification_code"
		case .frequentCodeRequest:
			return "frequent_verification_code_ request"
		}
	}
}

