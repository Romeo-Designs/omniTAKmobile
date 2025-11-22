//
//  ImageVariantSpecs.swift
//  Compiler
//
//  Created by Simon Corsin on 2/12/20.
//

import Foundation

class ImageVariantSpecs {
    let identifier: String

    let scale: Double
    let platform: Platform?

    let fileExtension: String

    let filenamePattern: String
    private let matchRegex: NSRegularExpression
    private let componentsCount: Int

    init(filenamePattern: String, scale: Double, platform: Platform?) {
        self.filenamePattern = filenamePattern
        self.scale = scale
        self.platform = platform

        if let platform = platform {
            self.identifier = "\(platform)-\(scale)"
        } else {
            self.identifier = "all-\(scale)"
        }

        self.fileExtension = String(filenamePattern.split(separator: ".").last!)

        self.componentsCount = filenamePattern.count { $0 == "/" } + 1

        let filePattern = filenamePattern.replacingOccurrences(of: ".", with: "\\.").replacingOccurrences(of: "$file", with: "(.*)")
        let regexStr = ".*/\(filePattern)$"

        self.matchRegex = try! NSRegularExpression(pattern: regexStr.replacingOccurrences(of: "/", with: "\\/"))
    }

    func matches(fileURL: URL) -> ImageAssetIdentifier? {
        let filePath = fileURL.path

        guard let textResult = fileURL.path.getMatch(regex: matchRegex) else {
            return nil
        }

        let fileRange = textResult.range(at: 1)

        guard let fileName = filePath.substring(with: fileRange) else {
            return nil
        }

        let assetName = fileName.replacingOccurrences(of: "-", with: "_")
        let assetDirectory = (0..<self.componentsCount).reduce(fileURL, { url, _ in url.deletingLastPathComponent() })

        return ImageAssetIdentifier(assetName: assetName, assetDirectory: assetDirectory)
    }

    func resolveFilename(assetName: String) -> String {
        return "\(filenamePattern.replacingOccurrences(of: "$file", with: assetName))"
    }
}
