import MediaPlayer
import UIKit

/// 锁屏 / 控制中心 / 耳机线控 / CarPlay 的信息与指令。
@MainActor
final class NowPlayingCenter {
    static let shared = NowPlayingCenter()

    private weak var player: AudioPlayer?
    private var isConfigured = false

    private init() {}

    func configure(player: AudioPlayer) {
        self.player = player
        guard !isConfigured else { return }
        isConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.toggle() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player?.previous() }
            return .success
        }

        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.nextTrackCommand, center.previousTrackCommand] {
            command.isEnabled = true
        }

        // 锁屏只显示播放进度；拖动跳转统一留在 App 内完成。
        center.changePlaybackPositionCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.isEnabled = false
    }

    /// 把当前歌曲同步到锁屏
    func refresh() {
        guard let player, let track = player.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        // 锁屏标题保留完整文件名，包括开头的序号和文件后缀；
        // 不经过标签或 FilenameParser，避免文件名被改写。
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? player.speed : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: player.speed,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        let artist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artist.isEmpty {
            info[MPMediaItemPropertyArtist] = artist
        }
        let album = track.album.trimmingCharacters(in: .whitespacesAndNewlines)
        if !album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let image = ArtworkStore.shared.image(for: track.artworkKey) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = player.isPlaying ? .playing : .paused
    }
}
