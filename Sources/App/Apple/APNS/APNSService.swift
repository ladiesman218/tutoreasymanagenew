//
//  File.swift
//
//
//  Created by Lei Gao on 2024/1/17.
//

import NIOCore
import NIOSSL
import APNS
import APNSCore
import Vapor

/*
 let tokens = try await APNSDevice.query(on: req.db).all().map { $0.tokenString() }
 let alertContent = APNSAlertNotificationContent(title: .raw("Morning"), subtitle: .raw("Time to code"), body: .raw("Enjoy a brand new day"), launchImage: nil)
 let alert = APNSAlertNotification(alert: alertContent, expiration: .immediately, priority: .immediately, topic: appleBundleID, payload: APNSService.Payload())
 try await APNSService.sendAlert(alert, to: tokens)
 */
struct APNSService {
	struct Payload: Codable {}
	static let appleECP8PrivateKey = Environment.get("APNS_PRIVATE_KEY")!.replacingOccurrences(of: ",", with: "\n")
	
	static let keyIdentifier = Environment.get("APNS_KEY_IDENTIFIER")!//"5323J2N9MN"
	static let teamIdentifier = Environment.get("APNS_TEAM_IDENTIFIER")!//"88XK97279C"
	
	@discardableResult
	static func sendAlert(_ content: APNSAlertNotification<Payload>, to deviceTokens: [String]) async throws -> [APNSResponse] {
		let client = APNSClient(
			configuration: .init(
				authenticationMethod: .jwt(
					privateKey: try .loadFrom(string: appleECP8PrivateKey),
					keyIdentifier: keyIdentifier,
					teamIdentifier: teamIdentifier
				),
				environment: .sandbox
			),
			eventLoopGroupProvider: .createNew,
			responseDecoder: JSONDecoder(),
			requestEncoder: JSONEncoder(),
			byteBufferAllocator: .init()
		)
		
		return try await withThrowingTaskGroup(of: APNSResponse.self) { group in
			var responses = [APNSResponse]()

			for token in deviceTokens {
				group.addTask {
					return try await client.sendAlertNotification(content, deviceToken: token)
				}
			}
			for try await response in group {
				responses.append(response)
			}
			
			defer {
				client.shutdown { error in
					if let error = error {
						let logger = Logger(label: "apns.tutoreasy.com")
						logger.error("\(error.localizedDescription)", metadata: ["function": #function])
					}
				}
			}
			return responses
		}
	}
}
