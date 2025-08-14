import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0.0 ... 1.0
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5
    var trackColor: Color = Color.secondary.opacity(0.2)
    var progressColor: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.easeInOut(duration: 0.2), value: progress)
//                .glassEffect()
//                .tint(progressColor)
        }
        .accessibilityLabel("Progress")
        .accessibilityValue(Text("\(Int(progress * 100)) percent"))
    }
}

#Preview("CircularProgressView") {
    VStack(spacing: 16) {
        CircularProgressView(progress: 0.35, size: 60, lineWidth: 6, progressColor: .yellow)
        CircularProgressView(progress: 0.8)
    }
    .padding()
}
