//
//  PhotoResultsListView.swift
//  bestPictureFinder
//
//  Extracted list component showing processed photos with swipe actions
//

import SwiftUI
import Photos

struct PhotoResultsListView: View {
    let processedImages: [ProcessedImage]
    let selectedIds: Set<String>
    let onToggleSelection: (ProcessedImage) -> Void
    let onShare: (ProcessedImage) -> Void
    let onDelete: (ProcessedImage) -> Void

    var body: some View {
        ZStack {
            List {
                ForEach(processedImages.indices, id: \.self) { index in
                    let image = processedImages[index]
                    ImageResultRow(
                        image: image,
                        rank: index + 1,
                        isSelected: selectedIds.contains(image.id),
                        onToggleSelection: { onToggleSelection(image) }
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture { onToggleSelection(image) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDelete(image) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { onShare(image) } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(selectedIds.contains(image.id) ? DesignColors.lightBlue : Color.white)
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .listRowSpacing(12)
            .scrollContentBackground(.hidden)
        }
        .frame(maxHeight: 520)
        .background(DesignColors.appBackground.ignoresSafeArea())
    }
}

struct ImageResultRow: View {
    let image: ProcessedImage
    let rank: Int
    let isSelected: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(rankHueColor(for: image.score))
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Image(uiImage: image.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(10)
            

                CircleRatingView(rating: normalizedScore05(from: image.score))
                    .frame(height: 80) // match thumbnail height for perfect vertical centering
                Text(String(format: "%.1f", normalizedScore05(from: image.score)))
                    .font(.subheadline)
                    .fontWeight(.semibold)


            Spacer()

            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)
            .foregroundColor(isSelected ? .blue : .secondary)
            .accessibilityLabel(isSelected ? "Selected" : "Not selected")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
    }

    // Per design: map score to hue from Red (0°) through Yellow (60°) to Green (120°)
    private func rankHueColor(for score: Double) -> Color {
        let t = max(0.0, min(1.0, (score + 100.0) / 200.0))
        let hueDegrees = 120.0 * t
        let hueFraction = hueDegrees / 360.0
        return Color(hue: hueFraction, saturation: 0.7, brightness: 0.92)
    }

    private func normalizedScore05(from rawScore: Double) -> Double {
        let clamped = max(-100.0, min(100.0, rawScore))
        return ((clamped + 100.0) / 200.0) * 5.0
    }
}

// Fractional 0..5 circle rating view with exact fill amount across five circles
struct CircleRatingView: View {
    let rating: Double // expected 0..5
    private let circleSize: CGFloat = 10
    private let spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { index in
                ZStack(alignment: .leading) {
                    Circle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: circleSize, height: circleSize)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: circleSize, height: circleSize)
                        .mask(LeadingClipShape(fraction: CGFloat(fillFraction(for: index))))
                }
            }
        }
        .accessibilityLabel("Rating \(String(format: "%.1f", rating)) out of 5")
    }

    private func fillFraction(for circleIndex: Int) -> Double {
        let remaining = rating - Double(circleIndex)
        return max(0.0, min(1.0, remaining))
    }
}

// A shape that reveals only the leading fraction (0..1) of its bounding rect width
struct LeadingClipShape: Shape {
    var fraction: CGFloat // 0..1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let width = max(0, min(rect.width, rect.width * fraction))
        p.addRect(CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
        return p
    }
}

#Preview("PhotoResultsListView") {
    let samples = SampleData.sampleProcessedImages(count: 5)
    PhotoResultsListView(
        processedImages: samples,
        selectedIds: Set(samples.prefix(2).map { $0.id }),
        onToggleSelection: { _ in },
        onShare: { _ in },
        onDelete: { _ in }
    )
    .padding()
    .background(DesignColors.appBackground)
}

enum SampleData {
    static func solidImage(color: UIColor, size: CGSize = CGSize(width: 60, height: 60)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func sampleProcessedImages(count: Int) -> [ProcessedImage] {
        var images: [ProcessedImage] = []
        for i in 0..<count {
            let ui = solidImage(color: [.systemBlue, .systemPink, .systemGreen, .systemOrange, .systemPurple][i % 5])
            let scoreSequence: [Double] = [-100, -50, 0, 50, 100]
            let score = scoreSequence[i % scoreSequence.count]
            let processed = ProcessedImage(id: UUID().uuidString, image: ui, score: score, originalIndex: i, asset: nil)
            images.append(processed)
        }
        return images
    }
}

