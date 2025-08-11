//
//  RatingBadgeView.swift
//  bestPictureFinder
//

import SwiftUI

struct RatingBadgeView: View {
    let score: Double // expected -100..100
    var diameter: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(hueColor(for: score))
                .frame(width: diameter, height: diameter)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            Text(String(format: "%.1f", normalizedScore05(from: score)))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    private func normalizedScore05(from raw: Double) -> Double {
        let clamped = max(-100.0, min(100.0, raw))
        return ((clamped + 100.0) / 200.0) * 5.0
    }

    private func hueColor(for score: Double) -> Color {
        let t = max(0.0, min(1.0, (score + 100.0) / 200.0))
        let hueDegrees = 120.0 * t
        let hueFraction = hueDegrees / 360.0
        // Slightly pastel tone per design refinement
        return Color(hue: hueFraction, saturation: 0.6, brightness: 0.9)
    }
}

