import Foundation

/// App 沙盒内的固定目录。
///
/// 音乐库的根目录就是 Documents 本身 —— 用户在「文件」App 里看到的就是这里，
/// 拖进来的文件立刻可见，不需要再往子目录里拷贝一份。
enum LibraryPaths {
    static let previewAudioName = "试听音乐(向左滑动删除).wav"

    static var root: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var artworkDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Artwork", isDirectory: true)
    }

    /// 别的 App 把文件「拷贝到本 App」时，系统会先丢在这里，我们再搬进库根目录
    static var inboxDirectory: URL {
        root.appendingPathComponent("Inbox", isDirectory: true)
    }

    static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    /// 首次启动放入一段可播放的原创试听音乐，保证空库时 Files 也能看到 App。
    static var previewAudio: URL {
        root.appendingPathComponent(previewAudioName, isDirectory: false)
    }

    /// 标签与封面缓存索引（键是相对路径，值里带大小和修改时间用来判失效）
    static var metadataFile: URL {
        supportDirectory.appendingPathComponent("metadata.json")
    }

    static func shouldRestorePreview(visibleNames: [String]) -> Bool {
        !visibleNames.contains {
            !$0.hasPrefix(".") && $0 != previewAudioName
        }
    }

    static func bootstrap() {
        let manager = FileManager.default
        for directory in [root, artworkDirectory, supportDirectory] {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // 清理早期版本创建的文本和隐藏占位文件。
        for legacyName in ["AnddleMusicPlayer_Keep.txt", ".anddle-music-player"] {
            try? manager.removeItem(
                at: root.appendingPathComponent(legacyName)
            )
        }

        guard !manager.fileExists(atPath: previewAudio.path) else { return }

        // 从上一版文件名迁移，避免重复出现两份试听音乐。
        let legacyPreview = root.appendingPathComponent("试听音乐.wav")
        if manager.fileExists(atPath: legacyPreview.path) {
            try? manager.moveItem(at: legacyPreview, to: previewAudio)
            return
        }

        let visibleNames = (try? manager.contentsOfDirectory(atPath: root.path)) ?? []
        guard shouldRestorePreview(visibleNames: visibleNames),
              let bundledPreview = Bundle.main.url(
                  forResource: "试听音乐(向左滑动删除)",
                  withExtension: "wav"
              ) else {
            return
        }
        try? manager.copyItem(at: bundledPreview, to: previewAudio)
    }

    /// 相对 Documents 的路径，用来做缓存键
    static func relativePath(of url: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        var relative = String(path.dropFirst(rootPath.count))
        while relative.hasPrefix("/") { relative.removeFirst() }
        return relative
    }

    static func url(forRelativePath path: String) -> URL {
        root.appendingPathComponent(path)
    }
}
