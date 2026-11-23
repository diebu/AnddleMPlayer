import SwiftUI

/// 在播放页向上滑出来的「接下来播放」
struct QueueSheet: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 16)

            HStack {
                Text("接下来播放")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(L10n.tracks(player.upNext.count))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 6)

            List {
                if let current = player.current {
                    MusicRowView(file: current, isCurrent: true, isPlaying: player.isPlaying)
                        .modifier(RowChrome())
                }
                ForEach(player.upNext) { file in
                    Button {
                        player.jump(to: file)
                        dismiss()
                    } label: {
                        MusicRowView(file: file, isCurrent: false, isPlaying: false)
                    }
                    .buttonStyle(.plain)
                    .modifier(RowChrome())
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Palette.background)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.background)
    }
}
