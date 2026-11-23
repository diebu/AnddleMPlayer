import SwiftUI

/// 顶部的轻提示
struct ToastView: View {
    var text: String?

    var body: some View {
        if let text {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Palette.surface, in: Capsule())
                .overlay(Capsule().stroke(Palette.line, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
