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


