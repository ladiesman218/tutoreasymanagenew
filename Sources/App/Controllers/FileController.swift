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
//        publicImageRoute.get("banner", "paths", use: getBannerPaths)
		
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
		
		let validOrders = try await ProtectedOrderController().getAllValidOrders(req)
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
		return req.fileio.streamFile(at: path)
    }
		
	func getCourseContent(_ req: Request) async throws -> Response {
		let url = try await accessibleURL(req)
		return req.fileio.streamFile(at: url.path)
	}
    
    func getBannerPaths(req: Request) -> [String] {
        var paths = [String]()
        for i in 1 ... 10 {
            for imageExtension in ImageExtension.allCases {
                let bannerURL = courseRoot.appendingPathComponent("banner\(i)", isDirectory: false).appendingPathExtension(imageExtension.rawValue)
                if FileManager.default.fileExists(atPath: bannerURL.path) {
                    paths.append(bannerURL.path)
                }
            }
        }
        return paths
    }
}


