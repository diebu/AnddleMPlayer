import SwiftUI

enum RowMetrics {
    static let height: CGFloat = 64
    static let columnWidth: CGFloat = 54
}

/// 行首那一列：窄窄一条，放类型标记。
/// 带一点底色和一条竖线，把「这是什么」和「它叫什么」分开 —— 文件管理器的常见做法。
struct TypeColumn<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: RowMetrics.columnWidth)
            .frame(maxHeight: .infinity)
            .background(Color.white.opacity(0.03))
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5)
            }
    }
}

/// 列里放什么：多选时是勾选圈，播放中是跳动的小柱子，其余是类型标记。
/// 音频在音符下面标出格式（MP3 / M4A / FLAC），SF Symbols 没有按格式分的图标，只能写字。
struct LeadContent: View {
    var isEditing: Bool
    var isSelected: Bool
    var symbol: String
    var tint: Color
    var formatLabel: String?
    var showsBars: Bool = false

    var body: some View {
        if isEditing {
            SelectCircle(isOn: isSelected)
        } else if showsBars {
            EqualizerBars()
        } else if let formatLabel, !formatLabel.isEmpty {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 17))
                Text(formatLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(tint)
        }
    }
}

/// 多选时的勾选圈
struct SelectCircle: View {
    @Environment(AppearanceStore.self) private var appearance
    var isOn: Bool

    var body: some View {
        ZStack {
            Circle().strokeBorder(isOn ? Color.clear : Palette.faint, lineWidth: 1.5)
            if isOn {
                Circle().fill(appearance.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.accentInk)
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// 元信息里的一个小图标加一个值：📅 2026-09-21、📁 0、📄 215
struct MetaItem: View {
    var symbol: String
    var text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11))
            Text(text).font(.system(size: 12)).monospacedDigit()
        }
        .foregroundStyle(Palette.faint)
    }
}

/// 列表里的细进度条：1pt 轨道、红色已播放部分和白色位置点。
struct ProgressLine: View {
    @Environment(AppearanceStore.self) private var appearance
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let value = fraction.isFinite ? fraction.clamped(to: 0...1) : 0
            let knobSize: CGFloat = 6
            let knobOffset = (width * value - knobSize / 2)
                .clamped(to: 0...max(0, width - knobSize))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: width, height: 1)
                Capsule()
                    .fill(appearance.accent)
                    .frame(width: max(0, width * value), height: 1)
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: appearance.accent.opacity(0.28), radius: 2)
                    .offset(x: knobOffset)
            }
            .frame(width: width, height: 8, alignment: .leading)
        }
        .frame(height: 8)
    }
}

/// 按扩展名挑一个 SF Symbol
enum FileIcon {
    /// iOS 原生解不了的音频格式：图标照样认成音频，但不参与播放
    static let unplayableAudio: Set<String> = [
        "wma", "ogg", "oga", "opus", "ape", "wv", "mpc",
        "amr", "mid", "midi", "mka", "dsf", "dff", "ra", "rm", "aax"
    ]

    static func isAudioLike(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return FileService.audioExtensions.contains(ext) || unplayableAudio.contains(ext)
    }

    static func symbol(for url: URL) -> String {
        if isAudioLike(url) { return "music.note" }
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "bmp", "tiff":
            return "photo"
        case "txt", "lrc", "md", "json", "xml", "csv", "srt", "ass":
            return "doc.text"
        default:
            return "doc"
        }
    }

    static func formatLabel(for url: URL) -> String? {
        isAudioLike(url) ? url.pathExtension.uppercased() : nil
    }
}

/// 文件夹行：名字 + 日期 / 子文件夹数 / 文件数
struct FolderRowView: View {
    var item: FolderItem
    var isEditing = false
    var isSelected = false

    var body: some View {
        HStack(spacing: 0) {
            TypeColumn {
                LeadContent(isEditing: isEditing, isSelected: isSelected,
                            symbol: "folder", tint: Palette.sub, formatLabel: nil)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    MetaItem(symbol: "calendar", text: fmtDate(item.modified))
                    MetaItem(symbol: "folder", text: "\(item.folderCount)")
                    MetaItem(symbol: "doc", text: "\(item.fileCount)")
                }
            }
            .padding(.leading, 14)

            Spacer(minLength: 8)
        }
        .padding(.trailing, 12)
        .frame(height: RowMetrics.height)
        .contentShape(Rectangle())
    }
}

/// 歌曲行：名字 + 进度条 + 已听时长 / 文件大小，右边是总时长
struct MusicRowView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppearanceStore.self) private var appearance
    var file: MusicFile
    var isCurrent: Bool
    var isPlaying: Bool
    var isEditing = false
    var isSelected = false

    /// 正在播的那一行直接用播放器的实时进度，其余用记录下来的。
    /// 记录里带着播放当时的时长，所以标签还没读完也不会显示成 0。
    private var progress: Double {
        if isCurrent, player.duration > 1 {
            return (player.elapsed / player.duration).clamped(to: 0...1)
        }
        return PlaybackProgress.shared.fraction(for: file)
    }

    private var metaText: String {
        var parts: [String] = []
        let played = isCurrent ? player.elapsed : PlaybackProgress.shared.position(for: file.relativePath)
        parts.append(played > 1 ? fmtTime(played) : "--:--")
        if file.sizeBytes > 0 {
            parts.append(FileService.formattedSize(file.sizeBytes))
        }
        return parts.joined(separator: " · ")
    }

    private var totalText: String? {
        if isCurrent, player.duration > 0 { return fmtTime(player.duration) }
        return file.duration > 0 ? fmtTime(file.duration) : nil
    }

    var body: some View {
        HStack(spacing: 0) {
            TypeColumn {
                LeadContent(isEditing: isEditing, isSelected: isSelected,
                            symbol: "music.note",
                            tint: isCurrent ? appearance.accent : Palette.faint,
                            formatLabel: file.formatLabel,
                            showsBars: isCurrent && isPlaying)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(file.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isCurrent ? appearance.accent : Palette.text)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    ProgressLine(fraction: progress)
                        .frame(width: 92)
                    Text(metaText)
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(Palette.faint)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 14)

            Spacer(minLength: 8)

            if let totalText {
                Text(totalText)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Palette.faint)
            }
        }
        .padding(.trailing, 16)
        .frame(height: RowMetrics.height)
        .contentShape(Rectangle())
    }
}

/// 非音频文件：压成灰色，能改名能删，但不参与播放
struct OtherRowView: View {
    var item: OtherItem
    var isEditing = false
    var isSelected = false

    var body: some View {
        HStack(spacing: 0) {
            TypeColumn {
                LeadContent(isEditing: isEditing, isSelected: isSelected,
                            symbol: FileIcon.symbol(for: item.url),
                            tint: Palette.faint,
                            formatLabel: FileIcon.formatLabel(for: item.url))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(1)
                Text(FileService.formattedSize(item.size))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Palette.faint)
            }
            .padding(.leading, 14)

            Spacer(minLength: 8)
        }
        .padding(.trailing, 16)
        .frame(height: RowMetrics.height)
        .contentShape(Rectangle())
    }
}
