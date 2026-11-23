import Foundation

/// 循环方式（和随机播放分开，跟系统音乐 App 的习惯一致）
enum RepeatMode: String, CaseIterable, Codable {
    /// 顺序播放，放完停
    case off
    /// 列表循环
    case all
    /// 单曲循环
    case one

    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    var symbolName: String {
        self == .one ? "repeat.1" : "repeat"
    }

    var title: String {
        switch self {
        case .off: return L10n.playbackInOrder
        case .all: return L10n.repeatAll
        case .one: return L10n.repeatOne
        }
    }

    var isActive: Bool { self != .off }
}

/// 列表排序方式
enum SortOrder: String, CaseIterable, Codable {
    case fileName
    case artist
    case album

    var title: String {
        switch self {
        case .fileName: return L10n.sortByFileName
        case .artist: return L10n.sortByArtist
        case .album: return L10n.sortByAlbum
        }
    }

    var symbolName: String {
        switch self {
        case .fileName: return "textformat.123"
        case .artist: return "person"
        case .album: return "square.stack"
        }
    }
}
