//
//  AnimatedGifView.swift
//  ExyteChat
//
//  Created by Claude Code
//

import SwiftUI
import UIKit
import ImageIO

/// A SwiftUI view that displays animated GIFs using native iOS frameworks
public struct GifViewRepresentable: UIViewRepresentable {
    let gifData: Data
    let contentMode: UIView.ContentMode

    public init(gifData: Data, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.gifData = gifData
        self.contentMode = contentMode
    }

    public func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        return imageView
    }

    public func updateUIView(_ uiView: UIImageView, context: Context) {
        // Create animated image from GIF data
        if let animatedImage = createAnimatedImage(from: gifData) {
            uiView.image = animatedImage
        }
    }

    /// Creates an animated UIImage from GIF data using ImageIO
    private func createAnimatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else {
            // Not an animated GIF, create static image
            return UIImage(data: data)
        }

        var images: [UIImage] = []
        var totalDuration: TimeInterval = 0

        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }

            // Get frame duration
            var frameDuration: TimeInterval = 0.1 // Default duration
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] {

                if let unclampedDelayTime = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber {
                    frameDuration = unclampedDelayTime.doubleValue
                } else if let delayTime = gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber {
                    frameDuration = delayTime.doubleValue
                }

                // Ensure minimum frame duration
                if frameDuration < 0.02 {
                    frameDuration = 0.1
                }
            }

            totalDuration += frameDuration
            images.append(UIImage(cgImage: cgImage))
        }

        guard !images.isEmpty else {
            return UIImage(data: data)
        }

        // Create animated image
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

/// A SwiftUI view that loads and displays an animated GIF from a URL with caching
public struct AnimatedGifView: View {
    let url: URL
    let size: CGSize

    @State private var gifData: Data?
    @State private var isLoading = true
    @State private var loadError: Error?

    public init(url: URL, size: CGSize = CGSize(width: 200, height: 200)) {
        self.url = url
        self.size = size
    }

    public var body: some View {
        Group {
            if let gifData = gifData {
                GifViewRepresentable(gifData: gifData, contentMode: .scaleAspectFill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(width: size.width, height: size.height)
            } else {
                // Fallback for failed loads
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .onAppear {
            loadGifData()
        }
    }

    private func loadGifData() {
        // Check cache first
        if let cachedData = GifCache.shared.get(for: url) {
            self.gifData = cachedData
            self.isLoading = false
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                // Cache the data
                GifCache.shared.set(data, for: url)

                await MainActor.run {
                    self.gifData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                }
                print("[AnimatedGifView] Failed to load GIF from \(url): \(error)")
            }
        }
    }
}

/// Simple in-memory cache for GIF data
final class GifCache {
    static let shared = GifCache()

    private var cache = NSCache<NSURL, NSData>()

    private init() {
        cache.countLimit = 50 // Max 50 GIFs cached
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB max
    }

    func get(for url: URL) -> Data? {
        return cache.object(forKey: url as NSURL) as Data?
    }

    func set(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
    }
}

/// Attachment view specifically for GIF attachments in the chat
public struct AnimatedGifAttachmentView: View {
    @Environment(\.chatTheme) var theme

    let attachment: Attachment
    let size: CGSize

    @State private var gifData: Data?
    @State private var isLoading = true

    public init(attachment: Attachment, size: CGSize) {
        self.attachment = attachment
        self.size = size
    }

    public var body: some View {
        Group {
            if let gifData = gifData {
                GifViewRepresentable(gifData: gifData, contentMode: .scaleAspectFill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading {
                ZStack {
                    Rectangle()
                        .foregroundColor(theme.colors.inputBG)
                    ActivityIndicator(size: 30, showBackground: false)
                }
                .frame(width: size.width, height: size.height)
            } else {
                // Fallback
                CachedAsyncImage(
                    url: attachment.thumbnail,
                    cacheKey: attachment.thumbnailCacheKey
                ) { imageView in
                    imageView
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } placeholder: {
                    ZStack {
                        Rectangle()
                            .foregroundColor(theme.colors.inputBG)
                        ActivityIndicator(size: 30, showBackground: false)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .onAppear {
            loadGifData()
        }
    }

    private func loadGifData() {
        let url = attachment.full

        // Check cache first
        if let cachedData = GifCache.shared.get(for: url) {
            self.gifData = cachedData
            self.isLoading = false
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                // Cache the data
                GifCache.shared.set(data, for: url)

                await MainActor.run {
                    self.gifData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("[AnimatedGifAttachmentView] Failed to load GIF: \(error)")
            }
        }
    }
}
