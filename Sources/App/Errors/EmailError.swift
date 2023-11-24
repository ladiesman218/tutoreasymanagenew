//
//  File.swift
//
//
//  Created by Lei Gao on 2023/11/24.
//

import Vapor

enum EmailError: Error {
	case unableToSend(response: ClientResponse)
	case messageBodyError(template: String, placeHolders: [String])
	case invalidRecipient(recipient: Email.Account)
	case invalidSender(sender: Email.Account)
	case invalidSubject
}

extension EmailError: DebuggableError, AbortError {
	var status: HTTPResponseStatus {
		switch self {
			case .unableToSend:
				return .internalServerError
			case .messageBodyError:
				return .badRequest
			case .invalidRecipient:
				return .badRequest
			case .invalidSender:
				return .badRequest
			case .invalidSubject:
				return .badRequest
		}
	}
	
	var reason: String {
		switch self {
			case .unableToSend(let response):
				return "无法发送邮件：\(response)"
			case .messageBodyError(let template, let placeHolders):
				return "邮件信息错误: 模板:\(template), 占位符：\(placeHolders) "
			case .invalidRecipient(let recipient):
				return "收件人错误: \(recipient)"
			case .invalidSender(let sender):
				return "发件人错误: \(sender)"
			case .invalidSubject:
				return "邮件标题错误"
		}
	}
	
	var identifier: String {
		switch self {
			case .unableToSend:
				return "unable_to_send_email"
			case .messageBodyError:
				return "email_message_body_error"
			case .invalidRecipient:
				return "invalid_recipient"
			case .invalidSender:
				return "invalid_sender"
			case .invalidSubject:
				return "invalid_subject"
		}
	}
}
