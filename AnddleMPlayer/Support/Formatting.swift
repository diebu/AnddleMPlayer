import Foundation

/// 秒数 → 3:45 / 1:02:03
func fmtTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    let s = total % 60
    let m = (total / 60) % 60
    let h = total / 3600
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%d:%02d", m, s)
}

/// 稳定（不随进程变化）的色相，用来给没有封面的歌生成占位配色
func stableHue(_ text: String) -> Double {
    var value = 7
    for scalar in text.unicodeScalars {
        value = (value &* 31 &+ Int(scalar.value)) % 360
    }
    return Double(value) / 360.0
}

/// 不预先指定行数，交给系统按实际宽度排版。
/// 括号内部使用 word joiner，避免右括号被单独挤到下一行。
func fileNameForNaturalWrapping(_ name: String) -> String {
    let opening: Set<Character> = ["(", "（", "[", "【", "《", "{", "「", "『"]
    let closing: Set<Character> = [")", "）", "]", "】", "》", "}", "」", "』"]
    let wordJoiner = "\u{2060}"
    let softBreak = "\u{200B}"

    var result = ""
    var bracketDepth = 0
    for character in name {
        if bracketDepth > 0 {
            result.append(wordJoiner)
        }
        result.append(character)

        if opening.contains(character) {
            bracketDepth += 1
        } else if closing.contains(character), bracketDepth > 0 {
            bracketDepth -= 1
        } else if bracketDepth == 0, character == "；" || character == ";" {
            result.append(softBreak)
        }
    }
    return result
}

/// 盘心文件夹名最多三行，按字符数尽量平均分配。
func balancedFileNameLines(
    _ name: String,
    preferredCharactersPerLine: Int = 3,
    maxLines: Int = 3
) -> String {
    let normalized = name
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
    let characters = Array(normalized)
    guard !characters.isEmpty else { return "" }

    let target = max(1, preferredCharactersPerLine)
    let lineCount = min(
        max(1, maxLines),
        max(1, Int(ceil(Double(characters.count) / Double(target))))
    )
    guard lineCount > 1 else { return normalized }

    let baseCount = characters.count / lineCount
    let extra = characters.count % lineCount
    var cursor = 0
    var lines: [String] = []

    for index in 0..<lineCount {
        let length = baseCount + (index < extra ? 1 : 0)
        let end = min(characters.count, cursor + length)
        lines.append(String(characters[cursor..<end]))
        cursor = end
    }
    return lines.joined(separator: "\n")
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// 行里显示的日期：2026-09-21
func fmtDate(_ date: Date?) -> String {
    guard let date else { return "—" }
    return dateFormatter.string(from: date)
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()
