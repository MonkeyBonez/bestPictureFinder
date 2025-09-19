import SwiftUI

enum GlassEffectStyle {
    case regularInteractive
}

struct GlassEffectIfAvailable: ViewModifier {
    var style: GlassEffectStyle = .regularInteractive

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
    }
}

extension View {
    func glassEffectIfAvailable(style: GlassEffectStyle = .regularInteractive) -> some View {
        modifier(GlassEffectIfAvailable(style: style))
    }
}


