//
//  File.swift
//  
//
//  Created by Lei Gao on 2022/11/3.
//

import Vapor

enum ChapterError: Error {
    case invalidURL
}

extension ChapterError: AbortError, DebuggableError {
    var status: HTTPResponseStatus {
        switch self {
        case .invalidURL:
            return .badRequest
        }
    }
    
    var reason: String {
        switch self {
        case .invalidURL:
            return "课程地址无效"
        }
    }
    
    var identifier: String {
        switch self {
        case .invalidURL:
            return "invalid_chapter_url"
        }
    }
}
