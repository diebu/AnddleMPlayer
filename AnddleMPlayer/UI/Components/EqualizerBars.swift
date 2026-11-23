import SwiftUI

/// 正在播放的那一行，序号位置显示的三根跳动小柱子
struct EqualizerBars: View {
    @Environment(AppearanceStore.self) private var appearance
    var isAnimating: Bool = true

    @State private var expanded = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            bar(height: 6, delay: 0.0)
            bar(height: 11, delay: 0.18)
            bar(height: 8, delay: 0.36)
        }
        .frame(height: 12, alignment: .bottom)
        .onAppear { expanded = true }
        .onDisappear { expanded = false }
    }

    private func bar(height: CGFloat, delay: Double) -> some View {
        Capsule(style: .continuous)
            .fill(appearance.accent)
            .frame(width: 2.5, height: height)
            .scaleEffect(y: isAnimating ? (expanded ? 1.0 : 0.35) : 0.6, anchor: .bottom)
            .animation(
                isAnimating
                    ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(delay)
                    : .default,
                value: expanded
            )
    }
}
