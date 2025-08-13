//
//  ProcessedImage.swift
//  bestPictureFinder
//

import UIKit
import Photos

public struct ProcessedImage: Identifiable {
    public let id: String
    public let image: UIImage
    public let score: Double // expected -100..100 range
    public let originalIndex: Int
    // We avoid fetching PHAsset during import to prevent permission prompts.
    // Store the Photos local identifier string (if available) for later resolution.
    public let assetLocalIdentifier: String?
    // Optional cached asset if already resolved elsewhere
    public let asset: PHAsset?
}

