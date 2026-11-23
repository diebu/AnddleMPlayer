import SwiftUI

/// 封面。没有内嵌封面时，用标题算出来的渐变配一个音符占位，
/// 保证每首歌都有自己的颜色，不会出现灰色缺图。
struct ArtworkView: View {
    var file: MusicFile?
    var cornerRadius: CGFloat = 14

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = ArtworkStore.shared.image(for: file?.artworkKey) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    PlaceholderArt()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct PlaceholderArt: View {
    @Environment(AppearanceStore.self) private var appearance

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Color.black
                LinearGradient(
                    colors: [
                        appearance.accent,
                        appearance.accent.opacity(0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: max(14, side * 0.3), weight: .light))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
    }
}
