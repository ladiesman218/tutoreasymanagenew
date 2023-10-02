//
//  File.swift
//  
//
//  Created by Lei Gao on 2023/9/18.
//

import Vapor

extension Request {
	/// This function generates a etag value for given content, compares the etag with request's .ifNoneMatch header(if there is one), returns .notModified if they match, or an Response with cache-control of the given case(when given) and .ok http status if not.
	/// - Parameters:
	///   - content: Content for generating eTagValue, and the actual response body. Needs to conform to CustomStringConvertible.
	///   - cacheControl: cacheControl for HTTP header, default to nil. It's only added if one option is given.
	/// - Returns: Response which will be returned for the request
    func response<T>(of content: T, cacheControl: HTTPHeaders.CacheControl? = nil) async throws -> Response where T: Content, T: CustomStringConvertible {
		// Generate etag
		let eTagValue = String(describing: content).persistantHash.description
		
		// Check if content has been cached already and return .notModified response if the etags match
		if eTagValue == self.headers.first(name: .ifNoneMatch) {
			return Response(status: .notModified)
		}
		
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .eTag, value: eTagValue)
		if let cacheControl = cacheControl {
            headers.cacheControl = cacheControl
		}
		let response = try await content.encodeResponse(status: .ok, headers: headers, for: self)
		return response
	}
}
