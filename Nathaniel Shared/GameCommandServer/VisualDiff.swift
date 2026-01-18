#if DEBUG

    import CoreGraphics
    import Foundation

    #if os(iOS) || os(tvOS)
        import UIKit

        typealias PlatformImage = UIImage
    #elseif os(macOS)
        import AppKit

        typealias PlatformImage = NSImage
    #endif

    /// Result of comparing two images
    public struct VisualDiffResult: Codable {
        /// Whether the images match (within threshold)
        public let match: Bool

        /// Percentage of pixels that differ (0.0 - 100.0)
        public let diffPercentage: Double

        /// Number of pixels that differ
        public let diffPixelCount: Int

        /// Total number of pixels compared
        public let totalPixels: Int

        /// Threshold used for comparison
        public let threshold: Double

        /// Base64-encoded diff image (if generated)
        public let diffImage: String?

        /// Error message if comparison failed
        public let error: String?

        public init(
            match: Bool,
            diffPercentage: Double,
            diffPixelCount: Int,
            totalPixels: Int,
            threshold: Double,
            diffImage: String? = nil,
            error: String? = nil
        ) {
            self.match = match
            self.diffPercentage = diffPercentage
            self.diffPixelCount = diffPixelCount
            self.totalPixels = totalPixels
            self.threshold = threshold
            self.diffImage = diffImage
            self.error = error
        }

        public static func failure(_ error: String) -> VisualDiffResult {
            VisualDiffResult(
                match: false,
                diffPercentage: 100.0,
                diffPixelCount: 0,
                totalPixels: 0,
                threshold: 0,
                diffImage: nil,
                error: error
            )
        }
    }

    /// Visual comparison utilities
    public enum VisualDiff {
        /// Compare two images and return the diff result
        /// - Parameters:
        ///   - image1Data: First image as PNG data
        ///   - image2Data: Second image as PNG data
        ///   - threshold: Percentage threshold for considering images as matching (0.0 - 100.0)
        ///   - generateDiffImage: Whether to generate a visual diff image
        /// - Returns: Comparison result
        public static func compare(
            _ image1Data: Data,
            _ image2Data: Data,
            threshold: Double = 1.0,
            shouldGenerateDiffImage: Bool = true
        ) -> VisualDiffResult {
            guard let cgImage1 = createCGImage(from: image1Data),
                  let cgImage2 = createCGImage(from: image2Data)
            else {
                return .failure("Failed to decode images")
            }

            // Images must be same size
            guard cgImage1.width == cgImage2.width, cgImage1.height == cgImage2.height else {
                let size1 = "\(cgImage1.width)x\(cgImage1.height)"
                let size2 = "\(cgImage2.width)x\(cgImage2.height)"
                return .failure("Image sizes don't match: \(size1) vs \(size2)")
            }

            let width = cgImage1.width
            let height = cgImage1.height
            let totalPixels = width * height

            // Get pixel data
            guard let pixels1 = getPixelData(from: cgImage1),
                  let pixels2 = getPixelData(from: cgImage2)
            else {
                return .failure("Failed to get pixel data")
            }

            // Compare pixels
            var diffPixelCount = 0
            var diffPixels: [Bool] = Array(repeating: false, count: totalPixels)

            for i in 0 ..< totalPixels {
                let offset = i * 4 // RGBA
                let r1 = pixels1[offset]
                let g1 = pixels1[offset + 1]
                let b1 = pixels1[offset + 2]

                let r2 = pixels2[offset]
                let g2 = pixels2[offset + 1]
                let b2 = pixels2[offset + 2]

                // Check if pixels differ (allowing small tolerance for compression artifacts)
                let tolerance: UInt8 = 2
                if abs(Int(r1) - Int(r2)) > Int(tolerance) ||
                    abs(Int(g1) - Int(g2)) > Int(tolerance) ||
                    abs(Int(b1) - Int(b2)) > Int(tolerance)
                {
                    diffPixelCount += 1
                    diffPixels[i] = true
                }
            }

            let diffPercentage = Double(diffPixelCount) / Double(totalPixels) * 100.0
            let match = diffPercentage <= threshold

            // Generate diff image if requested
            var diffImageBase64: String?
            if shouldGenerateDiffImage, diffPixelCount > 0 {
                if let diffImageData = generateDiffImage(
                    baseImage: cgImage1,
                    diffPixels: diffPixels,
                    width: width,
                    height: height
                ) {
                    diffImageBase64 = diffImageData.base64EncodedString()
                }
            }

            return VisualDiffResult(
                match: match,
                diffPercentage: diffPercentage,
                diffPixelCount: diffPixelCount,
                totalPixels: totalPixels,
                threshold: threshold,
                diffImage: diffImageBase64,
                error: nil
            )
        }

        // MARK: - Private Helpers

        private static func createCGImage(from data: Data) -> CGImage? {
            #if os(iOS) || os(tvOS)
                return UIImage(data: data)?.cgImage
            #elseif os(macOS)
                guard let image = NSImage(data: data),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else {
                    return nil
                }
                return cgImage
            #else
                return nil
            #endif
        }

        private static func getPixelData(from cgImage: CGImage) -> [UInt8]? {
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerPixel = 4
            let bytesPerRow = width * bytesPerPixel
            let bitsPerComponent = 8

            var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: &pixelData,
                      width: width,
                      height: height,
                      bitsPerComponent: bitsPerComponent,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                return nil
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return pixelData
        }

        private static func generateDiffImage(
            baseImage: CGImage,
            diffPixels: [Bool],
            width: Int,
            height: Int
        ) -> Data? {
            let bytesPerPixel = 4
            let bytesPerRow = width * bytesPerPixel
            let bitsPerComponent = 8

            // Get base image pixels
            guard var pixelData = getPixelData(from: baseImage) else {
                return nil
            }

            // Overlay diff highlights
            for i in 0 ..< diffPixels.count {
                if diffPixels[i] {
                    let offset = i * bytesPerPixel
                    // Highlight in red
                    pixelData[offset] = 255 // R
                    pixelData[offset + 1] = 0 // G
                    pixelData[offset + 2] = 0 // B
                    pixelData[offset + 3] = 255 // A
                } else {
                    // Dim non-diff areas
                    let offset = i * bytesPerPixel
                    pixelData[offset] = UInt8(Double(pixelData[offset]) * 0.3)
                    pixelData[offset + 1] = UInt8(Double(pixelData[offset + 1]) * 0.3)
                    pixelData[offset + 2] = UInt8(Double(pixelData[offset + 2]) * 0.3)
                }
            }

            // Create image from modified pixel data
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: &pixelData,
                      width: width,
                      height: height,
                      bitsPerComponent: bitsPerComponent,
                      bytesPerRow: bytesPerRow,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ),
                  let cgImage = context.makeImage()
            else {
                return nil
            }

            // Convert to PNG data
            #if os(iOS) || os(tvOS)
                return UIImage(cgImage: cgImage).pngData()
            #elseif os(macOS)
                let image = NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData)
                else {
                    return nil
                }
                return bitmap.representation(using: .png, properties: [:])
            #else
                return nil
            #endif
        }
    }

    // MARK: - Baseline Storage

    /// Manages baseline images for visual regression testing
    public class BaselineStorage {
        /// Shared instance
        public static let shared = BaselineStorage()

        /// Directory where baselines are stored
        private let baselineDirectory: URL

        /// In-memory cache of baselines
        private var cache: [String: Data] = [:]

        private init() {
            // Store baselines in app's documents directory
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            baselineDirectory = paths[0].appendingPathComponent("TestBaselines", isDirectory: true)

            // Create directory if needed
            try? FileManager.default.createDirectory(at: baselineDirectory, withIntermediateDirectories: true)
        }

        /// Save a baseline image
        /// - Parameters:
        ///   - name: Unique name for this baseline (e.g., "MainMenu_Default")
        ///   - imageData: PNG image data
        /// - Returns: Whether save was successful
        @discardableResult
        public func saveBaseline(name: String, imageData: Data) -> Bool {
            let sanitizedName = sanitizeName(name)
            let fileURL = baselineDirectory.appendingPathComponent("\(sanitizedName).png")

            do {
                try imageData.write(to: fileURL)
                cache[sanitizedName] = imageData
                return true
            } catch {
                print("[BaselineStorage] Failed to save baseline '\(name)': \(error)")
                return false
            }
        }

        /// Load a baseline image
        /// - Parameter name: Name of the baseline
        /// - Returns: PNG image data, or nil if not found
        public func loadBaseline(name: String) -> Data? {
            let sanitizedName = sanitizeName(name)

            // Check cache first
            if let cached = cache[sanitizedName] {
                return cached
            }

            // Load from disk
            let fileURL = baselineDirectory.appendingPathComponent("\(sanitizedName).png")
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }

            cache[sanitizedName] = data
            return data
        }

        /// Delete a baseline
        /// - Parameter name: Name of the baseline
        /// - Returns: Whether deletion was successful
        @discardableResult
        public func deleteBaseline(name: String) -> Bool {
            let sanitizedName = sanitizeName(name)
            let fileURL = baselineDirectory.appendingPathComponent("\(sanitizedName).png")

            cache.removeValue(forKey: sanitizedName)

            do {
                try FileManager.default.removeItem(at: fileURL)
                return true
            } catch {
                return false
            }
        }

        /// List all saved baselines
        /// - Returns: Array of baseline names
        public func listBaselines() -> [String] {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: baselineDirectory,
                includingPropertiesForKeys: nil
            ) else {
                return []
            }

            return contents
                .filter { $0.pathExtension == "png" }
                .map { $0.deletingPathExtension().lastPathComponent }
        }

        /// Check if a baseline exists
        /// - Parameter name: Name of the baseline
        /// - Returns: Whether the baseline exists
        public func hasBaseline(name: String) -> Bool {
            let sanitizedName = sanitizeName(name)
            let fileURL = baselineDirectory.appendingPathComponent("\(sanitizedName).png")
            return FileManager.default.fileExists(atPath: fileURL.path)
        }

        /// Clear all baselines
        public func clearAll() {
            cache.removeAll()
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: baselineDirectory,
                includingPropertiesForKeys: nil
            ) {
                for url in contents {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }

        private func sanitizeName(_ name: String) -> String {
            // Replace invalid filename characters
            let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
            return name.components(separatedBy: invalidChars).joined(separator: "_")
        }
    }

#endif
