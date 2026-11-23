import SwiftUI

/// 底部迷你播放条，点一下展开整屏播放页
struct MiniPlayerBar: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppearanceStore.self) private var appearance
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 11) {
                ArtworkView(file: player.current, cornerRadius: 8)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.current?.name ?? "")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                        .allowsTightening(true)
                    if let artist = player.current?.artist
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.sub)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            HStack(spacing: 18) {
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 19))
                        .frame(width: 26, height: 30)
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .frame(width: 26, height: 30)
                }
            }
            .foregroundStyle(Palette.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Palette.surface)
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Palette.line
                    appearance.accent.frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 2)
        }
    }

    private var progress: Double {
        guard player.duration > 0.1 else { return 0 }
        return (player.elapsed / player.duration).clamped(to: 0...1)
    }
}
