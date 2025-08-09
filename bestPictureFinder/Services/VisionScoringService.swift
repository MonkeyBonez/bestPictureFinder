//
//  VisionScoringService.swift
//  bestPictureFinder
//

import UIKit
import Vision

protocol VisionScoringServiceProtocol {
    func calculateScore(for image: UIImage) async -> Double
}

final class VisionScoringService: VisionScoringServiceProtocol {
    func calculateScore(for image: UIImage) async -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        let request = VNCalculateImageAestheticsScoresRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return 0.0
        }
        if let obs = request.results?.first as? VNImageAestheticsScoresObservation {
            // Convert to -100..100 range for downstream normalization (0..5)
            return Double(obs.overallScore) * 100.0
        }
        return 0.0
    }
}

