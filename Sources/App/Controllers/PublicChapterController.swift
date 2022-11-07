//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/11/3.
//

import Vapor

struct PublicChapterController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let chapters = routes.grouped("api", "chapter")
        chapters.get(":path", use: getChapter)
    }
    
    func getChapter(_ req: Request) throws -> Chapter {
        guard let pathString = req.parameters.get("path"), let path = URL(string: pathString) else {
            throw ChapterError.invalidURL
        }
        
        let chapter = Chapter(url: path)
        return chapter
    }
}
