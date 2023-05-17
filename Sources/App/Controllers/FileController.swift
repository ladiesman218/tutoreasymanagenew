//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/9/27.
//

import Vapor
import Fluent

struct FileController: RouteCollection {
	
	func boot(routes: Vapor.RoutesBuilder) throws {
		let publicImageRoute = routes.grouped("api", "image")
		publicImageRoute.get("**", use: publicGetImageData)
		
		let contentRoute = routes.grouped("api", "content").grouped(Token.authenticator())
		contentRoute.get("**", use: getCourseContent)
	}
	
	func accessibleURL(_ req: Request) async throws -> URL {
		let pathComponents = req.parameters.getCatchall()
		
		// Make sure the path is not directory
		let url = try pathComponents.generateURL()
		guard !url.isDirectory else {
			throw GeneralInputError.invalidURL }
		
		// coursesDirectoryName is where we put all course files, currently it's 'courses', following should be the name of the course, next should be the name for each stage's folder, then the name for chapter's folder. Offset coursesDirIndex by 3 to get chapter name
		guard let coursesDirIndex = pathComponents.firstIndex(of: coursesDirectoryName), pathComponents.count > coursesDirIndex + 3 else {
			throw GeneralInputError.invalidURL
		}
		
		// If chapter name contains string that indicate it's a free trial, return true directly.
		let chapterName = pathComponents[coursesDirIndex + 3]
		guard chapterName.range(of: trialChpaterRegex, options: .regularExpression) == nil else {
			return url
		}
		
		// Here means it's not a free trial.
		let courseName = pathComponents[coursesDirIndex + 1]
		// Make sure the given course is published
		guard try await Course.query(on: req.db).filter(\.$name == courseName).filter(\.$published == true).first() != nil else {
			throw CourseError.nameNotFound(name: courseName)
		}
		
		let validOrders = try await ProtectedOrderController().getAllValidOrders(req).content.decode([Order].self)
		// If an valid order contains the given course
		guard !validOrders.filter({ order in
			order.items.contains { $0.name == courseName }
		}).isEmpty else {
			throw CourseError.notPurchased(name: courseName)
		}
		return url
	}
	
	func publicGetImageData(req: Request) async throws -> Response {
		let pathComponents = req.parameters.getCatchall()
		// This is only for images
		guard let fileExtension = pathComponents.last?.split(separator: ".").last, ImageExtension.allCases.contains(where: { imageExtension in
			imageExtension.rawValue == String(fileExtension)
		}) else {
			throw Abort(.badRequest, reason: "This is for public images only")
		}
		
		let path = pathComponents.generatePath()
		let response = req.fileio.streamFile(at: path)
		// Same request in 1 second doesn't need revalidation, after expiration, in the following 1 year cached is served while revalidating.
		response.headers.replaceOrAdd(name: .cacheControl, value: "max-age=1, stale-while-revalidate=31536000")
		return response
	}
	
	func getCourseContent(_ req: Request) async throws -> Response {
		let url = try await accessibleURL(req)
		let path = url.path
		guard FileManager.default.fileExists(atPath: path) else {
			// For security reasons, do not show path or file name here
			throw CourseError.fileNotFound(name: "课程")
		}
		let response = req.fileio.streamFile(at: url.path)
		
		// no-cache means caches must check with the origin server for [validation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#Cache_validation) before using the cached copy.
		response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
		
		if response.headers.contentType?.type == "video" {
			response.headers.replaceOrAdd(name: .cacheControl, value: "no-store")
		}
		return response
	}
}


