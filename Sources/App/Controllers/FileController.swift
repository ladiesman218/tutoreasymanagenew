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
        contentRoute.on(.GET, "**", body: .stream, use: getCourseContent)
        
        let videoContentRoute = routes.grouped("api", "video")
        videoContentRoute.on(.GET, ":token", "**", body: .stream, use: getVideo)
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
	
    // This function only handles pdf file request, video file is handled by getVideo() function
	func getCourseContent(_ req: Request) async throws -> Response {
		let url = try await accessibleURL(req)

        let response = req.fileio.streamFile(at: url.path)
        
        response.headers.cacheControl = noCache
		
		return response
	}
    
    // Video content belongs to chapter content, the reason we need to define another function here to handle the request instead of using getCourseContent(), is becoz getCourseContent() is already guarded by token authenticator, but in client app, playing video needs to be done inside AVPlayerViewController, that controller doesn't support any authentication but a sole publicly accessible url. So we need a un-protected route to handle videos.
    func getVideo(_ req: Request) async throws -> Response {
		let url = try await accessibleURL(req)

        let response = req.fileio.streamFile(at: url.path)
        guard response.content.contentType?.type == "video" else { throw Abort(.internalServerError) }
        response.headers.cacheControl = noStore
        return response
    }
    
}

extension FileController {
    // Given a request, get all its url parameters, generate a file url from them, validate it should be accessed and return it, or throw an error if it shouldn't.
    private func accessibleURL(_ req: Request) async throws -> URL {
        let pathComponents = req.parameters.getCatchall()
        // coursesDirectoryName is where we put all course files, currently it's 'Courses', following should be the name of the course, followed by the name of each stage's folder, then the name of chapter's folder. Offset coursesDirIndex by 3 to get chapter name
        guard let coursesDirIndex = pathComponents.firstIndex(of: coursesDirectoryName), pathComponents.count > coursesDirIndex + 3 else {
            throw GeneralInputError.invalidURL
        }
        
        let courseName = pathComponents[coursesDirIndex + 1]
        // Make sure the given course is published
        guard try await Course.query(on: req.db).filter(\.$name == courseName).filter(\.$published == true).first() != nil else {
            throw CourseError.nameNotFound(name: courseName)
        }
        
        // Make sure the path is not directory and file exists
        let url = try pathComponents.generateURL()
        guard !url.isDirectory else { throw GeneralInputError.invalidURL }
        guard FileManager.default.fileExists(atPath: url.path) else {
            // For security reasons, do not show path or file name here
            throw CourseError.fileNotFound(name: "课程")
        }
                
        // If chapter name contains string that indicate it's a free trial, return the url directly.
        let chapterName = pathComponents[coursesDirIndex + 3]
        if chapterName.contains(trialRegex) {
            return url
        }
        
        // Here means it's not a free trial.
        let user: User
        // User can be got by 2 different ways: for normal pdf requests, `try req.auth.require(User.self)` will do. For video file requests, it's got by passing token in request parameter.
        if let token = req.parameters.get("token") {
            // When testing, if token value is an empty string, like `{{host}}/api/video//Users/leigao/myProjects/Courses/幼儿园英语课程/WOW1/第1课：五官/五官双师堂.mp4`, vapor will take `Users` as the token, hence entire path will be wrong and fileNotFound will be thrown.
            guard let foundToken = try await Token.query(on: req.db).filter(\.$value == token).with(\.$user).first() else {
                throw AuthenticationError.invalidLoginNameOrPassword
            }
            user = foundToken.user
        } else {
            user = try req.auth.require(User.self)
        }
        
        let allOrders = try await OrderController.getAllOrders(req, for: user)
        let validOrders = OrderController.filterAllValidOrders(orders: allOrders)
        
        if validOrders.filter({ order in
            order.items.contains { $0.name == courseName }
        }).isEmpty {
            throw CourseError.notPurchased(name: courseName)
        }
        return url
    }
}
