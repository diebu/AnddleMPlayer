import Foundation

/// 代码中拼接出来的文案无法由 SwiftUI 自动本地化，统一从这里取翻译。
enum L10n {
    static func key(_ value: String) -> String {
        NSLocalizedString(value, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: self.key(key), locale: .current, arguments: arguments)
    }

    private static func oneOrMany(
        _ count: Int,
        one: String,
        many: String
    ) -> String {
        count == 1 ? key(one) : format(many, count)
    }

    static func items(_ count: Int) -> String {
        oneOrMany(count, one: "count.item.one", many: "count.items")
    }

    static func folders(_ count: Int) -> String {
        oneOrMany(count, one: "count.folder.one", many: "count.folders")
    }

    static func files(_ count: Int) -> String {
        oneOrMany(count, one: "count.file.one", many: "count.files")
    }

    static func tracks(_ count: Int) -> String {
        oneOrMany(count, one: "count.track.one", many: "count.tracks")
    }

    static func audioFiles(_ count: Int) -> String {
        oneOrMany(count, one: "count.audioFile.one", many: "count.audioFiles")
    }

    static func emptyFolders(_ count: Int) -> String {
        oneOrMany(count, one: "count.emptyFolder.one", many: "count.emptyFolders")
    }

    static func minutes(_ count: Int) -> String {
        oneOrMany(count, one: "count.minute.one", many: "count.minutes")
    }

    static func compactMinutes(_ count: Int) -> String {
        format("count.minutes.compact", count)
    }

    static func compactSeconds(_ count: Int) -> String {
        format("count.seconds.compact", count)
    }

    // MARK: 固定文案

    static var music: String { key("音乐") }
    static var unknownArtist: String { key("未知艺术家") }
    static var unknown: String { key("未知") }
    static var selectAll: String { key("全选") }
    static var deselectAll: String { key("取消全选") }
    static var chooseDestination: String { key("选择目标文件夹") }
    static var startTimer: String { key("开始倒计时") }
    static var cancelTimer: String { key("取消定时") }
    static var noAudioFiles: String { key("这个文件夹里没有音频文件") }

    static var invalidName: String { key("名字不能为空") }
    static var nameTaken: String { key("这个名字已经存在了") }
    static var moveIntoSelf: String { key("不能把文件夹移动到它自己里面") }

    static var playbackInOrder: String { key("顺序播放") }
    static var repeatAll: String { key("列表循环") }
    static var repeatOne: String { key("单曲循环") }

    static var sortByFileName: String { key("按文件名") }
    static var sortByArtist: String { key("按歌手") }
    static var sortByAlbum: String { key("按专辑") }

    // MARK: 动态提示

    static func about(_ appName: String) -> String {
        format("about.title", appName)
    }

    static func version(_ version: String) -> String {
        format("about.version", version)
    }

    static func created(_ name: String) -> String {
        format("toast.created", name)
    }

    static func renamed(_ name: String) -> String {
        format("toast.renamed", name)
    }

    static func moved(_ count: Int) -> String {
        format("toast.moved", items(count))
    }

    static var alreadyAtDestination: String { key("已经在目标文件夹里了") }
    static var importFailedPrefix: String { key("导入失败：") }
    static var noNewImportContent: String { key("没有可导入的新内容") }

    static func imported(_ count: Int) -> String {
        format("toast.imported", items(count))
    }

    static func audioImportSummary(
        imported: Int,
        skippedEmptyFolders: Int
    ) -> String {
        if imported == 0 {
            return skippedEmptyFolders > 0
                ? key("toast.noAudioFolders")
                : key("toast.noAudioSelected")
        }
        if skippedEmptyFolders == 0 {
            return format("toast.importedAudio", audioFiles(imported))
        }
        return format(
            "toast.importedAudio.skipped",
            audioFiles(imported),
            emptyFolders(skippedEmptyFolders)
        )
    }

    static func received(_ count: Int) -> String {
        format("toast.received", items(count))
    }

    static var receiveFailed: String { key("这份内容没能收进来") }

    static func deleted(_ name: String) -> String {
        format("toast.deleted.name", name)
    }

    static func deletedFolders(_ count: Int) -> String {
        format("toast.deleted.folders", count)
    }

    static func deletedFiles(_ count: Int) -> String {
        format("toast.deleted.files", count)
    }

    static func deletedMixed(folders: Int, files: Int) -> String {
        format("toast.deleted.mixed", self.folders(folders), self.files(files))
    }

    static func sleepScheduled(minutes: Int) -> String {
        format("toast.sleep.scheduled", self.minutes(minutes))
    }

    static func sleepScheduled(tracks: Int) -> String {
        format("toast.sleep.scheduled.tracks", self.tracks(tracks))
    }

    static var sleepCancelled: String { key("已取消定时") }
    static var sleepTimeElapsed: String { key("定时到点，已暂停") }

    static func sleepTracksElapsed(_ count: Int) -> String {
        format("toast.sleep.elapsed.tracks", tracks(count))
    }

    static func speedAccessibility(_ speed: String) -> String {
        format("accessibility.speed", speed)
    }

    // MARK: 文件信息

    static func titleInfo(_ title: String) -> String {
        format("info.title", title)
    }

    static func artistInfo(_ artist: String) -> String {
        format("info.artist", artist)
    }

    static func albumInfo(_ album: String) -> String {
        format("info.album", album)
    }

    static func durationInfo(_ duration: String) -> String {
        format("info.duration", duration)
    }

    // MARK: 定时状态

    static func remainingMinutesSeconds(minutes: Int, seconds: Int) -> String {
        format("timer.remaining.minutesSeconds", minutes, seconds)
    }

    static func compactTimer(minutes: Int, seconds: Int) -> String {
        format("timer.remaining.clock", minutes, seconds)
    }

    static func remainingSeconds(_ seconds: Int) -> String {
        format("timer.remaining.seconds", seconds)
    }

    static func remainingTracks(_ tracks: Int) -> String {
        format("timer.remaining.tracks", self.tracks(tracks))
    }
}
