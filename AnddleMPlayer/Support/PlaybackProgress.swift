import Foundation
import Observation

/// 该从哪儿开始播：听过一点才续播，刚开头（等于没听）和快听完了（接上去等于直接结束）都从头来。
/// 时长还不知道时（`duration <= 0`）不猜，照续。
func resumeTarget(saved: Double, duration: Double) -> Double {
    guard saved.isFinite, saved > 3 else { return 0 }
    if duration > 0, duration - saved < 5 { return 0 }
    return saved
}

/// 一次播放记录。
///
/// 记了**当时的时长**，所以进度条不依赖标签读没读到 ——
/// 刚导入的文件标签还没读完时，标签里的时长是 0，只按它算进度会一直显示 0。
struct PlaybackPosition: Codable {
    var seconds: Double
    var duration: Double

    var fraction: Double {
        guard duration > 1 else { return 0 }
        return (seconds / duration).clamped(to: 0...1)
    }
}

/// 每个文件播到哪儿了。按相对路径记，列表里画成一条细进度条。
/// 只记播过的文件，没播过的没有记录。
@MainActor
@Observable
final class PlaybackProgress {
    static let shared = PlaybackProgress()

    private static let key = "playbackPositions"

    private var positions: [String: PlaybackPosition]
    private var lastFlush = Date.distantPast

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: PlaybackPosition].self, from: data) {
            positions = saved
        } else {
            positions = [:]
        }
    }

    func position(for path: String) -> Double {
        positions[path]?.seconds ?? 0
    }

    /// 播放记录里保存的真实时长，可在标签尚未加载时作为进度条量程。
    func duration(for path: String) -> Double {
        positions[path]?.duration ?? 0
    }

    /// 0…1，用来画进度条
    func fraction(for file: MusicFile) -> Double {
        guard let record = positions[file.relativePath] else { return 0 }
        let knownDuration = record.duration > 0 ? record.duration : file.duration
        guard knownDuration > 1 else { return 0 }
        return (record.seconds / knownDuration).clamped(to: 0...1)
    }

    /// 该从哪儿接着播
    func resumeStart(for file: MusicFile) -> Double {
        guard let record = positions[file.relativePath] else { return 0 }
        let known = record.duration > 0 ? record.duration : file.duration
        return resumeTarget(saved: record.seconds, duration: known)
    }

    func hasProgress(_ file: MusicFile) -> Bool {
        positions[file.relativePath] != nil
    }

    /// 播放中会不停调用。变化太小就丢掉，免得每 0.2 秒都动一次 UserDefaults。
    /// 切歌、暂停等明确节点传 `force`，保证最终位置立即写入。
    func record(
        _ path: String,
        seconds: Double,
        duration: Double,
        force: Bool = false
    ) {
        guard seconds.isFinite, seconds >= 0 else { return }
        if !force,
           let existing = positions[path],
           abs(existing.seconds - seconds) < 3,
           abs(existing.duration - duration) < 1 {
            return
        }
        positions[path] = PlaybackPosition(seconds: seconds, duration: duration)
        if force || Date().timeIntervalSince(lastFlush) > 5 {
            flush()
        }
    }

    func clear(_ path: String) {
        guard positions[path] != nil else { return }
        positions.removeValue(forKey: path)
        flush()
    }

    /// 删除文件夹时只清理该文件夹下面的路径，不影响其他文件。
    func clearDescendants(of path: String) {
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let removed = positions.keys.filter { $0.hasPrefix(prefix) }
        guard !removed.isEmpty else { return }
        for child in removed {
            positions.removeValue(forKey: child)
        }
        flush()
    }

    func flush() {
        lastFlush = Date()
        guard let data = try? JSONEncoder().encode(positions) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
