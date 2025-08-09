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
    public let asset: PHAsset?
}

