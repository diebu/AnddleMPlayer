import Foundation

/// 资源管理器要用的文件操作：增、删、改、查。
enum FileService {
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "m4r", "aac", "aif", "aiff", "aifc", "caf", "wav", "flac", "alac"
    ]

    static func isAudio(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    static func children(of directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [] }
        return items
    }

    static func itemCount(of directory: URL) -> Int {
        children(of: directory).count
    }

    /// 一个文件夹的概况：子文件夹数、文件数、修改时间。
    /// 只遍历一层，行里显示「📅 日期 📁 0 📄 215」用。
    static func summary(of directory: URL) -> (folders: Int, files: Int, modified: Date?) {
        let keys: [URLResourceKey] = [.isDirectoryKey]
        var folders = 0
        var files = 0
        for item in children(of: directory) {
            if (try? item.resourceValues(forKeys: Set(keys)))?.isDirectory == true {
                folders += 1
            } else {
                files += 1
            }
        }
        let modified = (try? directory.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return (folders, files, modified)
    }

    /// 这一层里的音频，不往子文件夹里钻 —— 播放队列就是它
    static func audioURLs(in directory: URL) -> [URL] {
        children(of: directory)
            .filter { !isDirectory($0) && isAudio($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// 递归收集整棵目录树的音频，只用于清理缓存这类全库操作
    static func allAudioURLs(in directory: URL = LibraryPaths.root, depth: Int = 0) -> [URL] {
        guard depth < 8 else { return [] }
        var result: [URL] = []
        for item in children(of: directory) {
            if isDirectory(item) {
                result.append(contentsOf: allAudioURLs(in: item, depth: depth + 1))
            } else if isAudio(item) {
                result.append(item)
            }
            if result.count >= 5000 { break }
        }
        return result
    }

    static func size(of url: URL) -> Int64 {
        if isDirectory(url) {
            var total: Int64 = 0
            if let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
            ) {
                for case let child as URL in enumerator {
                    total += Int64((try? child.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                }
            }
            return total
        }
        return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    static func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: 新增

    /// 接收系统分享或“在 App 中打开”传入的本地文件。
    ///
    /// 普通文件夹保留文件夹本身；如果选中的是某个 App 的 Documents，
    /// 则把 Documents 里的直接内容导入当前目录，不额外套一层 Documents。
    @discardableResult
    static func importItems(
        _ urls: [URL],
        into destination: URL
    ) throws -> Int {
        var copied = 0
        for source in urls {
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }

            copied += copySource(source, into: destination)
        }
        return copied
    }

    struct AudioImportResult {
        var importedAudio = 0
        var skippedEmptyFolders = 0

        var isEmpty: Bool {
            importedAudio == 0 && skippedEmptyFolders == 0
        }
    }

    /// 从其他 App 导入时只复制播放器支持的音频文件。
    /// 文件夹会保留音频所在的目录结构，但忽略其他格式和空目录。
    @discardableResult
    static func importAudioItems(
        _ urls: [URL],
        into destination: URL
    ) -> AudioImportResult {
        var result = AudioImportResult()
        for source in urls {
            let accessed = source.startAccessingSecurityScopedResource()
            defer {
                if accessed { source.stopAccessingSecurityScopedResource() }
            }

            if isDirectory(source) {
                guard containsAudio(in: source) else {
                    result.skippedEmptyFolders += 1
                    continue
                }
                if source.lastPathComponent.caseInsensitiveCompare("Documents") == .orderedSame {
                    result.importedAudio += copyAudioChildren(of: source, into: destination)
                } else {
                    let target = uniqueURL(
                        in: destination,
                        preferredName: source.lastPathComponent
                    )
                    do {
                        try FileManager.default.createDirectory(
                            at: target,
                            withIntermediateDirectories: false
                        )
                        result.importedAudio += copyAudioChildren(of: source, into: target)
                    } catch {
                        continue
                    }
                }
            } else if isAudio(source), copyOne(source, into: destination) != nil {
                result.importedAudio += 1
            }
        }
        return result
    }

    static func containsAudio(in directory: URL, depth: Int = 0) -> Bool {
        guard depth < 16 else { return false }
        for item in children(of: directory) {
            if isDirectory(item) {
                if containsAudio(in: item, depth: depth + 1) { return true }
            } else if isAudio(item) {
                return true
            }
        }
        return false
    }

    private static func copyAudioChildren(of source: URL, into destination: URL) -> Int {
        var copied = 0
        for item in children(of: source) {
            if isDirectory(item) {
                guard containsAudio(in: item) else { continue }
                let target = uniqueURL(
                    in: destination,
                    preferredName: item.lastPathComponent
                )
                do {
                    try FileManager.default.createDirectory(
                        at: target,
                        withIntermediateDirectories: false
                    )
                    copied += copyAudioChildren(of: item, into: target)
                } catch {
                    continue
                }
            } else if isAudio(item), copyOne(item, into: destination) != nil {
                copied += 1
            }
        }
        return copied
    }

    private static func copySource(_ source: URL, into destination: URL) -> Int {
        if isDirectory(source),
           source.lastPathComponent.caseInsensitiveCompare("Documents") == .orderedSame {
            var copied = 0
            for child in children(of: source) {
                if copyOne(child, into: destination) != nil {
                    copied += 1
                }
            }
            return copied
        }
        return copyOne(source, into: destination) == nil ? 0 : 1
    }

    /// 拷一项。文件按「同名同大小」判断是不是同一个；文件夹一律另起名字，不合并也不覆盖。
    private static func copyOne(_ source: URL, into destination: URL) -> URL? {
        let manager = FileManager.default
        let preferred = source.lastPathComponent
        let direct = destination.appendingPathComponent(preferred)
        let exists = manager.fileExists(atPath: direct.path)
        if exists, !isDirectory(source), size(of: source) == size(of: direct) {
            return nil
        }
        let target = exists ? uniqueURL(in: destination, preferredName: preferred) : direct
        do {
            try manager.copyItem(at: source, to: target)
            return target
        } catch {
            return nil
        }
    }

    @discardableResult
    static func createFolder(in parent: URL, named name: String) throws -> URL {
        let trimmed = sanitize(name)
        guard !trimmed.isEmpty else { throw FileError.invalidName }
        let target = uniqueURL(in: parent, preferredName: trimmed)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        return target
    }

    // MARK: 改名

    // MARK: 接收外部分享

    /// 接住从「文件」或其他 App 分享进来的东西，落到库根目录。
    ///
    /// 两种到达方式要分开处理：in-place（`LSSupportsOpeningDocumentsInPlace`）给的是
    /// 原位置的 URL，需要拷贝；「拷贝到 App」给的是我们沙盒 Inbox 里的 URL，搬出来即可，
    /// 不然会在库里多出一个 Inbox 文件夹。
    @discardableResult
    static func accept(
        _ urls: [URL],
        inbox: URL = LibraryPaths.inboxDirectory,
        into destination: URL = LibraryPaths.root
    ) -> Int {
        var accepted = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let source = url.standardizedFileURL
            if source.path.hasPrefix(inbox.standardizedFileURL.path + "/") {
                if moveOut(source, into: destination) { accepted += 1 }
            } else {
                accepted += (try? importItems([source], into: destination)) ?? 0
            }
        }
        return accepted
    }

    /// 把 Inbox 里积压的东西全部搬进库根目录（App 冷启动时兜一次底）
    @discardableResult
    static func drainInbox(
        inbox: URL = LibraryPaths.inboxDirectory,
        into destination: URL = LibraryPaths.root
    ) -> Int {
        let children = children(of: inbox)
        guard !children.isEmpty else { return 0 }
        let accepted = accept(children, inbox: inbox, into: destination)
        try? FileManager.default.removeItem(at: inbox)
        return accepted
    }

    private static func moveOut(_ source: URL, into destination: URL) -> Bool {
        let manager = FileManager.default
        guard source.deletingLastPathComponent().standardizedFileURL != destination.standardizedFileURL else {
            return false
        }
        let direct = destination.appendingPathComponent(source.lastPathComponent)
        let target = manager.fileExists(atPath: direct.path)
            ? uniqueURL(in: destination, preferredName: source.lastPathComponent)
            : direct
        do {
            try manager.moveItem(at: source, to: target)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String) throws -> URL {
        let isDir = isDirectory(url)
        var name = sanitize(newName)
        guard !name.isEmpty else { throw FileError.invalidName }
        let ext = url.pathExtension
        if !isDir, !ext.isEmpty, (name as NSString).pathExtension.isEmpty {
            name += "." + ext          // 用户只改了主名，扩展名保留
        }
        let target = url.deletingLastPathComponent().appendingPathComponent(name)
        guard target.standardizedFileURL != url.standardizedFileURL else { return url }
        guard !FileManager.default.fileExists(atPath: target.path) else { throw FileError.nameTaken }
        try FileManager.default.moveItem(at: url, to: target)
        return target
    }

    // MARK: 移动

    @discardableResult
    static func move(_ urls: [URL], to destination: URL) throws -> Int {
        let manager = FileManager.default
        let destPath = destination.standardizedFileURL.path
        var moved = 0
        for source in urls {
            let srcPath = source.standardizedFileURL.path
            if isDirectory(source), destPath == srcPath || destPath.hasPrefix(srcPath + "/") {
                throw FileError.moveIntoSelf
            }
            guard source.deletingLastPathComponent().standardizedFileURL.path != destPath else { continue }
            let direct = destination.appendingPathComponent(source.lastPathComponent)
            let target = manager.fileExists(atPath: direct.path)
                ? uniqueURL(in: destination, preferredName: source.lastPathComponent)
                : direct
            try manager.moveItem(at: source, to: target)
            moved += 1
        }
        return moved
    }

    // MARK: 删除

    struct DeleteResult {
        /// 真的从磁盘上删掉的
        var deleted = 0
        /// 只断开引用的（文件不在我们沙盒里，原文件一根汗毛都不能动）
        var unlinked = 0
    }

    /// 删除一批条目。沙盒里的物理删除；沙盒外的一律只断引用 ——
    /// 这条规则是硬性的，宁可少删也绝不误删别人的文件。
    @discardableResult
    static func delete(_ urls: [URL], root: URL = LibraryPaths.root) throws -> DeleteResult {
        var result = DeleteResult()
        let rootPath = root.standardizedFileURL.path
        for url in urls {
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(rootPath + "/") else {
                result.unlinked += 1
                continue
            }
            try FileManager.default.removeItem(at: url)
            result.deleted += 1
        }
        return result
    }

    // MARK: 工具

    static func uniqueURL(in parent: URL, preferredName: String) -> URL {
        let manager = FileManager.default
        let direct = parent.appendingPathComponent(preferredName)
        if !manager.fileExists(atPath: direct.path) { return direct }
        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var index = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let candidate = parent.appendingPathComponent(name)
            if !manager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private static func sanitize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
    }

    enum FileError: LocalizedError {
        case invalidName
        case nameTaken
        case moveIntoSelf

        var errorDescription: String? {
            switch self {
            case .invalidName: return L10n.invalidName
            case .nameTaken: return L10n.nameTaken
            case .moveIntoSelf: return L10n.moveIntoSelf
            }
        }
    }
}
