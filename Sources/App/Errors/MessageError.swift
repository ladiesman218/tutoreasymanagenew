//
//  File.swift
//
//
//  Created by Lei Gao on 2023/11/24.
//

import Vapor

enum MessageError: Error {
	case unableToSend(response: ClientResponse)
	case messageBodyError(template: String, placeHolders: [String])
	case invalidEmailRecipient(recipient: String)
	case invalidSMSRecipient(recipient: String)
	case invalidEmailSender(sender: Email.Account)
	case invalidEmailSubject
}

extension MessageError: DebuggableError, AbortError {
	var status: HTTPResponseStatus {
		switch self {
			case .unableToSend:
				return .internalServerError
			case .messageBodyError:
				return .badRequest
			case .invalidEmailRecipient, .invalidSMSRecipient:
				return .badRequest
			case .invalidEmailSender:
				return .badRequest
			case .invalidEmailSubject:
				return .badRequest
		}
	}
	
	var reason: String {
		switch self {
			case .unableToSend(let response):
				return "邮件或短信发送失败：\(response)"
			case .messageBodyError(let template, let placeHolders):
				return "邮件信息错误: 模板:\(template), 占位符：\(placeHolders) "
			case .invalidEmailRecipient(let recipient):
				return "收件人错误: \(recipient)"
			case .invalidSMSRecipient(let recipient):
				return "短信号码错误: \(recipient)"
			case .invalidEmailSender(let sender):
				return "发件人错误: \(sender)"
			case .invalidEmailSubject:
				return "邮件标题错误"
		}
	}
	
	var identifier: String {
		switch self {
			case .unableToSend:
				return "unable_to_send_email"
			case .messageBodyError:
				return "email_message_body_error"
			case .invalidEmailRecipient(let recipient):
				return "invalid_email_recipient: \(recipient)"
			case .invalidSMSRecipient(let recipient):
				return "invalid_sms_recipient: \(recipient)"
			case .invalidEmailSender:
				return "invalid_sender"
			case .invalidEmailSubject:
				return "invalid_subject"
		}
	}
}
