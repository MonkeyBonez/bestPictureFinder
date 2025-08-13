import SwiftUI

struct LiquidGlassToast: View {
    let message: String
    var expansionDuration: TimeInterval = 0.5
    var overshootFactor: CGFloat = 1.07
    var contractionDuration: TimeInterval = 2.3
    var holdDuration: TimeInterval? = 0.3
    var closeDuration: TimeInterval = 0.35
    var tapToClose: Bool = true
    var onDismiss: (() -> Void)? = nil
    
    @State private var measuredWidth: CGFloat = 0
    @State private var currentWidth: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var hasAnimatedOpen: Bool = false
    @State private var isClosingRequested: Bool = false
    @State private var contractionWorkItem: DispatchWorkItem? = nil
    @State private var closeWorkItem: DispatchWorkItem? = nil

    var body: some View {
        ZStack(alignment: .center) {
            // Measure target size using the exact styled text
            Text(message)
                .font(.footnote)
                .padding(.horizontal, 15)
                .fixedSize(horizontal: true, vertical: true)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                measuredWidth = proxy.size.width
                                if !hasAnimatedOpen {
                                    hasAnimatedOpen = true
                                    startOpenAnimation()
                                }
                            }
                    }
                )
                .hidden()

            // Visible liquid-glass capsule that expands from center
            ZStack {
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: true, vertical: true)
                    .opacity(textOpacity)
            }
            .frame(width: max(currentWidth, 0), alignment: .center)
            .opacity(currentWidth > 0 ? 1 : 0.001)
            .clipped()
            .background(.bar, in: Capsule())
            .glassEffect()
            .contentShape(Capsule())
            .onTapGesture {
                guard tapToClose else { return }
                requestCloseNow()
            }
        }
        .accessibilityLabel(message)
        .onDisappear { cancelScheduledAnimations() }
    }


    private func startOpenAnimation() {
        currentWidth = 0
        textOpacity = 0
        // 1) Expand with slight overshoot
        withAnimation(.easeOut(duration: expansionDuration)) {
            currentWidth = max(measuredWidth * overshootFactor, 0)
        }
        // Fade text in during expand
        withAnimation(.easeIn(duration: expansionDuration)) {
            textOpacity = 1
        }
        // 2) After expand, decay back to target width
        let contraction = DispatchWorkItem {
            if isClosingRequested { return }
            withAnimation(.easeOut(duration: contractionDuration)) {
                currentWidth = max(measuredWidth, 0)
            }
            // 3) After decay + hold, close
            let hold = max(0, holdDuration ?? 0)
            let closeItem = DispatchWorkItem {
                if isClosingRequested { return }
                startCloseAnimation()
            }
            closeWorkItem = closeItem
            DispatchQueue.main.asyncAfter(deadline: .now() + contractionDuration + hold, execute: closeItem)
        }
        contractionWorkItem = contraction
        DispatchQueue.main.asyncAfter(deadline: .now() + expansionDuration, execute: contraction)
    }

    private func startCloseAnimation() {
        // Fade text out first, then collapse width
        withAnimation(.smooth(duration: 0.2)) {
            textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.smooth(duration: closeDuration)) {
                currentWidth = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + closeDuration) {
                onDismiss?()
            }
        }
    }

    private func requestCloseNow() {
        guard !isClosingRequested else { return }
        isClosingRequested = true
        cancelScheduledAnimations()
        startCloseAnimation()
    }

    private func cancelScheduledAnimations() {
        contractionWorkItem?.cancel()
        contractionWorkItem = nil
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }
}

#Preview("LiquidGlassToast") {
    ZStack(alignment: .top) {
        Color.black.opacity(0.05).ignoresSafeArea()
        LiquidGlassToast(message: "Liquid Glass Toast")
            .padding(.top, 10)
    }
}



