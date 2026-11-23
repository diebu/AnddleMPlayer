import Foundation

/// 一首本地歌曲。路径一律存相对 Documents 的相对路径 —— 沙盒的绝对路径
/// 在重装、迁移之后会变，存绝对路径下次启动就找不到文件了。
struct MusicFile: Identifiable, Hashable {
    var relativePath: String
    var name: String
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var duration: Double = 0
    /// 文件大小，列表里跟已听时长并排显示
    var sizeBytes: Int64 = 0
    /// 封面在 Caches/Artwork 下的文件名
    var artworkKey: String?

    var id: String { relativePath }

    var url: URL { LibraryPaths.url(forRelativePath: relativePath) }

    /// 列表里显示的名字：有标签用标签，没有就退回文件名
    var displayTitle: String {
        title.isEmpty ? (name as NSString).deletingPathExtension : title
    }

    var displayArtist: String {
        artist.isEmpty ? L10n.unknownArtist : artist
    }

    var subtitle: String {
        let parts = [artist, album].filter { !$0.isEmpty }
        return parts.isEmpty ? name : parts.joined(separator: " · ")
    }

    /// 行首显示的格式标记：MP3 / M4A / FLAC…
    var formatLabel: String {
        (name as NSString).pathExtension.uppercased()
    }

    /// 歌曲直接所在文件夹的名称；音乐库根目录显示为「音乐」。
    var containingFolderName: String {
        let parent = (relativePath as NSString).deletingLastPathComponent
        guard !parent.isEmpty, parent != "." else { return L10n.music }
        let name = (parent as NSString).lastPathComponent
        return name.isEmpty ? L10n.music : FilenameParser.folderDisplayName(name)
    }

    static func == (lhs: MusicFile, rhs: MusicFile) -> Bool {
        lhs.relativePath == rhs.relativePath && lhs.title == rhs.title && lhs.duration == rhs.duration
    }

    func hash(into hasher: inout Hasher) { hasher.combine(relativePath) }
}
