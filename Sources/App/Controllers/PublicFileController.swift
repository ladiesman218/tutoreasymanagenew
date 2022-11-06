//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/9/27.
//

import Vapor
	
struct PublicFileController: RouteCollection {
    
    func boot(routes: Vapor.RoutesBuilder) throws {
        let fileRoute = routes.grouped("api", "file")
        fileRoute.get("**", use: getFileData)
        fileRoute.get("banner", "paths", use: getBannerPaths)
    }
    
    func getFileData(req: Request) -> Response {
        
        let pathComponents = req.parameters.getCatchall()
        let path = "/" + String(pathComponents.joined(by: "/"))
        
        // Can't access paths above the app's root directory by default, so manually insert "../" before.
        //        let joinedPath = "../" + String(paths.joined(by: "/"))
        
        // Get banner images
        //        if joinedPath.hasPrefix("../Courses/banner") {
        //            for `extension` in ImageExtension.allCases {
        //                if FileManager.default.fileExists(atPath: joinedPath.appending(".\(`extension`.rawValue)")) {
        //                    return req.fileio.streamFile(at: joinedPath.appending(".\(`extension`.rawValue)"))
        //                }
        //            }
        //        }
        
        // joinedPath will be url encoded automatically, so here it's safe to force generate a url from it.
        //        let pathString = URL(string: joinedPath)!.absoluteString
        
        //        let path = pathString.removingPercentEncoding ?? pathString
        //        return req.fileio.streamFile(at: joinedPath, mediaType: .init(type: "image", subType: "*"))
        return req.fileio.streamFile(at: path)
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


