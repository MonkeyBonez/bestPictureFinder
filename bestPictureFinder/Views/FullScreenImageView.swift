//
//  FullScreenImageView.swift
//  bestPictureFinder
//

import SwiftUI

struct FullScreenImageView: View {
    let images: [UIImage]
    @State private var index: Int
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isVisible: Bool = false
    let heroNamespace: Namespace.ID?
    let sourceId: String?
    let targetThumbnailFrame: CGRect?
    @State private var isClosing: Bool = false

    // Explicit initializer so callers can pass the starting index despite @State
    init(images: [UIImage], index: Int, onClose: (() -> Void)? = nil, heroNamespace: Namespace.ID? = nil, sourceId: String? = nil, targetThumbnailFrame: CGRect? = nil) {
        self.images = images
        self._index = State(initialValue: max(0, min(index, images.count - 1)))
        self.onClose = onClose
        self.heroNamespace = heroNamespace
        self.sourceId = sourceId
        self.targetThumbnailFrame = targetThumbnailFrame
    }

    var body: some View {
        ZStack(alignment: .center) {
            Rectangle()
                .glassEffect(.regular.interactive(), in: .containerRelative)
                .ignoresSafeArea()
                .onTapGesture { handleClose() }

            Image(uiImage: images[index])
                .resizable()
                .clipShape(.containerRelative)
                .aspectRatio(contentMode: .fit)
                .padding(.horizontal, 44)
                .padding(.vertical, 60)
                .modifier(MatchedGeometryIfAvailable(id: sourceId, ns: heroNamespace))
                .opacity(usesLocalAppearAnimation ? (isVisible ? 1 : 0) : 1)
                .scaleEffect(isClosing ? scaleDuringClose : (usesLocalAppearAnimation ? (isVisible ? 1.0 : 0.99) : 1.0), anchor: .center)
                .background(FrameReader())
                .offset(closeOffset)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: index)
                .animation(.easeInOut(duration: 0.2), value: isVisible)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isClosing)

//            Button(action: { dismiss() }) {
//                Image(systemName: "xmark.circle.fill")
//                    .foregroundColor(.secondary)
//                    .font(.system(size: 30, weight: .semibold))
//                    .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
//                    .padding(16)
//            }
//            .accessibilityLabel("Close")
        }
        .onAppear {
            if usesLocalAppearAnimation {
                withAnimation(.easeInOut(duration: 0.5)) { isVisible = true }
            }
        }
        .onDisappear {
            // Reset closing flag after the view is removed to avoid a re-render using non-closing path
            isClosing = false
        }
    }

    private func handleClose() {
        if usesLocalAppearAnimation {
            withAnimation(.easeInOut(duration: 0.2)) { isVisible = false }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { isClosing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                if let onClose { onClose() } else { dismiss() }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { isClosing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                if let onClose { onClose() } else { dismiss() }
            }
        }
    }

    private var usesLocalAppearAnimation: Bool { heroNamespace == nil || sourceId == nil }
    private var closeOffset: CGSize {
        guard isClosing, let thumb = targetThumbnailFrame, let full = FrameReader.lastFullFrame else { return .zero }
        // Compute vector from fullscreen image center to thumbnail center in screen space
        let fullCenter = CGPoint(x: full.midX, y: full.midY)
        let thumbCenter = CGPoint(x: thumb.midX, y: thumb.midY)
        return CGSize(width: thumbCenter.x - fullCenter.x, height: thumbCenter.y - fullCenter.y)
    }
    private var scaleDuringClose: CGFloat {
        guard isClosing, let thumb = targetThumbnailFrame, let full = FrameReader.lastFullFrame else { return 1.0 }
        let sx = max(0.0001, thumb.width / max(1, full.width))
        let sy = max(0.0001, thumb.height / max(1, full.height))
        // Use the smaller ratio to maintain aspect without overshooting
        return min(sx, sy)
    }

    private struct FrameReader: View {
        static var lastFullFrame: CGRect?
        var body: some View {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { FrameReader.lastFullFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { newValue in
                        FrameReader.lastFullFrame = newValue
                    }
            }
        }
    }

    private struct MatchedGeometryIfAvailable: ViewModifier {
        let id: String?
        let ns: Namespace.ID?
        func body(content: Content) -> some View {
            if let id, let ns {
                content.matchedGeometryEffect(id: id, in: ns, properties: .position)
            } else {
                content
            }
        }
    }
}

#if DEBUG
#Preview("FullScreenImageView") {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
    func sample(_ color: UIColor) -> UIImage {
        renderer.image { ctx in
            color.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }
    }
    return FullScreenImageView(images: [sample(.systemBlue), sample(.systemTeal)], index: 0)
}
#endif

