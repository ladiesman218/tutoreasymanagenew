//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/12/1.
//

import Vapor


struct ProtectedFileController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let protectedFileRoot = routes.grouped("api", "file", "protected")//.grouped(User.authenticator(), Token.authenticator()).grouped(User.guardMiddleware())
		
		
	}
	
	func getFileData(req: Request) -> Response {
		
		let pathComponents = req.parameters.getCatchall()
		let path = "/" + String(pathComponents.joined(by: "/"))
		
		return req.fileio.streamFile(at: path)
	}
	
}
