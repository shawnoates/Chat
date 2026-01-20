//
//  URL+GIF.swift
//  ExyteChat
//
//  Created by Claude Code
//

import Foundation

public extension URL {
    /// Checks if this URL points to a GIF file
    var isGifUrl: Bool {
        let urlString = absoluteString.lowercased()
        return urlString.hasSuffix(".gif") ||
               urlString.contains("giphy.com") ||
               urlString.contains("tenor.com") ||
               urlString.contains("/gif/") ||
               urlString.contains("media.giphy.com")
    }
}

public extension String {
    /// Checks if this string URL points to a GIF file
    var isGifUrl: Bool {
        let lowercased = self.lowercased()
        return lowercased.hasSuffix(".gif") ||
               lowercased.contains("giphy.com") ||
               lowercased.contains("tenor.com") ||
               lowercased.contains("/gif/") ||
               lowercased.contains("media.giphy.com")
    }
}
