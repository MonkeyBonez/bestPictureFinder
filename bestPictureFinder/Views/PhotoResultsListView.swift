//
//  PhotoResultsListView.swift
//  bestPictureFinder
//
//  Extracted list component showing processed photos with swipe actions
//

import SwiftUI
import Photos
import UIKit

struct PhotoResultsListView: View {
    let processedImages: [ProcessedImage]
    let selectedIds: Set<String>
    let onToggleSelection: (ProcessedImage) -> Void
    let onShare: (ProcessedImage) -> Void
    let onDelete: (ProcessedImage) -> Void
    let onOpenOverlay: ([UIImage], Int, String) -> Void
    let heroNamespace: Namespace.ID
    let activeSourceId: String?
    let onReportThumbnailFrame: (_ id: String, _ frameInScreen: CGRect) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            List {
                ForEach(processedImages.indices, id: \.self) { index in
                    let image = processedImages[index]
                    ImageResultRow(
                        image: image,
                        rank: index + 1,
                        isSelected: selectedIds.contains(image.id),
                        onToggleSelection: { onToggleSelection(image) },
                        allImages: processedImages,
                        currentIndex: index,
                        onOpenOverlay: { images, startIndex, sourceId in onOpenOverlay(images, startIndex, sourceId) },
                        heroNamespace: heroNamespace,
                        activeSourceId: activeSourceId,
                        onReportThumbnailFrame: onReportThumbnailFrame
                    )
//                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture { onToggleSelection(image) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDelete(image) } label: {
                            Label("Remove", systemImage: "minus.circle.fill")
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
                            .fill({ () -> Color in
                                let isSelected = selectedIds.contains(image.id)
                                if isSelected {
                                    let t = max(0.0, min(1.0, (image.score + 100.0) / 200.0))
                                    let hueDegrees = 120.0 * t
                                    let hueFraction = hueDegrees / 360.0
                                    let base = Color(hue: hueFraction, saturation: 0.7, brightness: 0.92)
                                    return base.opacity(colorScheme == .dark ? 0.40 : 0.18)
                                } else {
                                    return Color(colorScheme == .dark ? .secondarySystemBackground : .white)
                                }
                            }())
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .listRowSpacing(12)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 24)
        }
//        .frame(maxHeight: 520)no 
        .background(DesignColors.appBackground(for: colorScheme))
    }
}

struct ImageResultRow: View {
    let image: ProcessedImage
    let rank: Int
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let allImages: [ProcessedImage]
    let currentIndex: Int
    let onOpenOverlay: ([UIImage], Int, String) -> Void
    let heroNamespace: Namespace.ID
    let activeSourceId: String?
    let onReportThumbnailFrame: (_ id: String, _ frameInScreen: CGRect) -> Void
    @State private var tapPulse: Bool = false

    var body: some View {
        HStack(spacing: 20) {
            ThumbnailView(
                image: image.image,
                size: 80,
                cornerRadius: 15,
                matchedGeometryId: image.id,
                heroNamespace: heroNamespace
            )
            .opacity(activeSourceId == image.id ? 0 : 1)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { onReportThumbnailFrame(image.id, proxy.frame(in: .global)) }
                        .onChange(of: proxy.frame(in: .global)) { newValue in
                            onReportThumbnailFrame(image.id, newValue)
                        }
                }
            )
            .onTapGesture { onOpenOverlay(allImages.map { $0.image }, currentIndex, image.id) }
            .accessibilityLabel("Open photo fullscreen")
            .accessibilityHint("Double tap to view and swipe to dismiss")
            .shadow(
                color: Color.black.opacity(0.4),
                radius: 4,
                x: 0,
                y: 3
            )
            .scaleEffect(tapPulse ? 0.98 : 1.0)
            HStack(spacing: 14) {
                CircleRatingView(
                    rating: normalizedScore05(from: image.score),
                    fillColor: rankHueColor(for: image.score)
                )
                .shadow(
                    color: isSelected ? Color.black.opacity(0.18) : .clear,
                    radius: 6,
                    x: 0,
                    y: 3
                )
                .scaleEffect(tapPulse ? 0.98 : 1.0)
                Spacer(minLength: 0)
                Button(action: performToggleSelectionHaptic) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .scaleEffect((isSelected ? 1.08 : 1.0) * (tapPulse ? 1.12 : 1.0))
                }
                .buttonStyle(.plain)
                .foregroundColor(isSelected ? rankHueColor(for: image.score) : .secondary)
                .accessibilityLabel(isSelected ? "Selected" : "Not selected")
                .accessibilityValue(Text("Score \(String(format: "%.1f", normalizedScore05(from: image.score))) out of 5"))
                .accessibilityHint("Double tap to toggle selection")
                .shadow(
                    color: isSelected ? Color.black.opacity(0.24) : .clear,
                    radius: 6,
                    x: 0,
                    y: 3
                )
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: performToggleSelectionHaptic)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.18, dampingFraction: 0.9), value: isSelected)
        .animation(.spring(response: 0.12, dampingFraction: 0.9), value: tapPulse)
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

    // MARK: - Haptics
    private func performToggleSelectionHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tapPulse = true
        withAnimation(.spring(response: 0.16, dampingFraction: 0.9)) {
            onToggleSelection()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            tapPulse = false
        }
    }
}

// Fractional 0..5 circle rating view with exact fill amount across five circles
struct CircleRatingView: View {
    let rating: Double // expected 0..5
    var fillColor: Color = .yellow
    private let circleSize: CGFloat = 14
    private let spacing: CGFloat = 4.5

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { index in
                ZStack(alignment: .leading) {
                    Circle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: circleSize, height: circleSize)
                    Circle()
                        .fill(fillColor)
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
    PreviewContainer()
        .padding()
        .background(DesignColors.lightModeBackground)
}

struct PreviewContainer: View {
    @Namespace var ns
    var body: some View {
        let samples = SampleData.sampleProcessedImages(count: 5)
        return PhotoResultsListView(
            processedImages: samples,
            selectedIds: Set(samples.prefix(2).map { $0.id }),
            onToggleSelection: { _ in },
            onShare: { _ in },
            onDelete: { _ in },
            onOpenOverlay: { _, _, _ in },
            heroNamespace: ns,
            activeSourceId: nil,
            onReportThumbnailFrame: { _, _ in }
        )
    }
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
            let processed = ProcessedImage(
                id: UUID().uuidString,
                image: ui,
                score: score,
                originalIndex: i,
                assetLocalIdentifier: nil,
                asset: nil
            )
            images.append(processed)
        }
        return images
    }
}

