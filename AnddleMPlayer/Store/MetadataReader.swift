import AVFoundation
import Foundation

struct AudioMetadata {
    var title = ""
    var artist = ""
    var album = ""
    var duration: Double = 0
    var artwork: Data?
}

/// 用 AVFoundation 读取音频文件的内嵌标签与封面。
enum MetadataReader {
    /// iOS 原生能解码的格式（APE / WMA / OGG 这些系统不支持，导入时会跳过）
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "m4r", "aac", "aif", "aiff", "aifc", "caf", "wav", "flac", "alac"
    ]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func read(url: URL) async -> AudioMetadata {
        var meta = AudioMetadata()
        let asset = AVURLAsset(url: url)

        if let duration = try? await asset.load(.duration), duration.isNumeric, duration.seconds.isFinite {
            meta.duration = max(0, duration.seconds)
        }

        var items: [AVMetadataItem] = []
        if let common = try? await asset.load(.commonMetadata) {
            items.append(contentsOf: common)
        }
        if let all = try? await asset.load(.metadata) {
            items.append(contentsOf: all)
        }

        for item in items {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if meta.title.isEmpty, let value = try? await item.load(.stringValue) {
                    meta.title = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case .commonKeyArtist:
                if meta.artist.isEmpty, let value = try? await item.load(.stringValue) {
                    meta.artist = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case .commonKeyAlbumName:
                if meta.album.isEmpty, let value = try? await item.load(.stringValue) {
                    meta.album = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case .commonKeyArtwork:
                if meta.artwork == nil, let data = try? await item.load(.dataValue) {
                    meta.artwork = data
                }
            default:
                break
            }
        }

        // 标签缺失时用文件名兜底
        if meta.title.isEmpty || meta.artist.isEmpty {
            let guess = FilenameParser.parse(url.lastPathComponent)
            if meta.title.isEmpty { meta.title = guess.title }
            if meta.artist.isEmpty { meta.artist = guess.artist }
        }

        return meta
    }
}
