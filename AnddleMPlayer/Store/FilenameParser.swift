import Foundation

/// 没有标签信息时，从文件名里猜歌手和歌名。
enum FilenameParser {
    struct Guess {
        var title = ""
        var artist = ""
    }

    private static let artistTitle = try? NSRegularExpression(
        pattern: "^(?:track\\s*)?(?:\\d{1,3}[.\\-\\s_]+)?(.{1,40}?)\\s*[-–—]\\s*(.{1,60})$"
    )
    private static let trackOnly = try? NSRegularExpression(
        pattern: "^\\d{1,3}[.\\-\\s_]+(.{1,60})$"
    )
    private static let leadingSequence = try? NSRegularExpression(
        pattern: "^(?:[\\[(（]\\s*\\d{1,4}\\s*[\\])）]\\s*|(?:第\\s*)?\\d{1,4}\\s*[章节集部卷]?\\s*(?:[.、:：\\-_]\\s*|\\s+))"
    )

    /// 盘心文件夹名去掉目录排序用的数字前缀。
    static func folderDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let leadingSequence else { return trimmed }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = leadingSequence.firstMatch(in: trimmed, range: range),
              let matchRange = Range(match.range, in: trimmed) else {
            return trimmed
        }
        let result = String(trimmed[matchRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? trimmed : result
    }

    static func parse(_ fileName: String) -> Guess {
        var guess = Guess()
        let base = (fileName as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return guess }

        let range = NSRange(base.startIndex..<base.endIndex, in: base)

        if let regex = artistTitle,
           let match = regex.firstMatch(in: base, options: [], range: range),
           match.numberOfRanges == 3,
           let artistRange = Range(match.range(at: 1), in: base),
           let titleRange = Range(match.range(at: 2), in: base) {
            let artist = String(base[artistRange]).trimmingCharacters(in: .whitespaces)
            let title = String(base[titleRange]).trimmingCharacters(in: .whitespaces)
            if !artist.isEmpty, !title.isEmpty {
                guess.artist = artist
                guess.title = title
                return guess
            }
        }

        if let regex = trackOnly,
           let match = regex.firstMatch(in: base, options: [], range: range),
           match.numberOfRanges == 2,
           let titleRange = Range(match.range(at: 1), in: base) {
            let title = String(base[titleRange]).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                guess.title = title
                return guess
            }
        }

        guess.title = base
        return guess
    }
}
