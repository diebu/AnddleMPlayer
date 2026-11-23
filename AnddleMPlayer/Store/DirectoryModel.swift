import Foundation
import Observation

struct FolderItem: Identifiable, Hashable {
    var url: URL
    var folderCount: Int = 0
    var fileCount: Int = 0
    var modified: Date?
    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
    var totalCount: Int { folderCount + fileCount }
}

struct OtherItem: Identifiable, Hashable {
    var url: URL
    var size: Int64
    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
}

/// 一个目录（或「全部音乐」）的列表数据与文件操作。
@MainActor
@Observable
final class DirectoryModel {
    /// 当前展示的目录，以及它是不是根目录（只影响标题样式）
    let directory: URL
    let isRoot: Bool
    private(set) var folders: [FolderItem] = []
    private(set) var music: [MusicFile] = []
    private(set) var others: [OtherItem] = []
    private(set) var loading = true
    var selection = Set<String>()
    var isEditing = false

    private var loadToken = 0
    private let byName: (String, String) -> Bool = {
        $0.localizedStandardCompare($1) == .orderedAscending
    }

    init(directory: URL, isRoot: Bool) {
        self.directory = directory
        self.isRoot = isRoot
    }

    var isEmpty: Bool { folders.isEmpty && music.isEmpty && others.isEmpty }

    var selectedURLs: [URL] {
        allURLs.filter { selection.contains($0.standardizedFileURL.path) }
    }

    /// 当前目录里的所有条目的 URL，按显示顺序
    var allURLs: [URL] {
        folders.map(\.url) + music.map(\.url) + others.map(\.url)
    }

    var selectedCount: Int { selection.count }

    var allSelected: Bool {
        !allURLs.isEmpty && selection.count == allURLs.count
    }

    /// 全选 / 取消全选
    func toggleSelectAll() {
        if allSelected {
            selection.removeAll()
        } else {
            selection = Set(allURLs.map { $0.standardizedFileURL.path })
        }
    }

    // MARK: 载入

    func load() async {
        let token = beginLoad()
        await load(token: token)
    }

    private func beginLoad() -> Int {
        loadToken += 1
        loading = true
        return loadToken
    }

    private func load(token: Int) async {
        // 只看这一层：文件夹自己走，音频进列表，其余当普通文件
        var folderItems: [FolderItem] = []
        var audioURLs: [URL] = []
        var otherItems: [OtherItem] = []

        for item in FileService.children(of: directory) {
            if FileService.isDirectory(item) {
                let summary = FileService.summary(of: item)
                folderItems.append(FolderItem(
                    url: item,
                    folderCount: summary.folders,
                    fileCount: summary.files,
                    modified: summary.modified
                ))
            } else if FileService.isAudio(item) {
                audioURLs.append(item)
            } else {
                otherItems.append(OtherItem(url: item, size: FileService.size(of: item)))
            }
        }

        audioURLs.sort { byName($0.lastPathComponent, $1.lastPathComponent) }

        guard token == loadToken else { return }
        folders = folderItems.sorted { byName($0.name, $1.name) }
        others = otherItems.sorted { byName($0.name, $1.name) }
        music = audioURLs.map { MetadataStore.shared.musicFile(for: $0) }
        loading = false

        // 标签是逐个用 AVFoundation 读的，很慢。刷新动画不该等它 ——
        // 列表先出来，没读过的那些在后台慢慢补。
        Task { [weak self] in
            await self?.fillMissingMetadata(audioURLs, token: token)
        }
    }

    /// 缓存里没有的歌逐个异步读标签，读完就刷新对应的那一行
    private func fillMissingMetadata(_ urls: [URL], token: Int) async {
        for url in urls {
            if Task.isCancelled || token != loadToken { return }
            guard MetadataStore.shared.cached(for: url) == nil else { continue }
            await MetadataStore.shared.ensure(url)
            guard token == loadToken else { return }
            let key = LibraryPaths.relativePath(of: url)
            if let index = music.firstIndex(where: { $0.relativePath == key }) {
                music[index] = MetadataStore.shared.musicFile(for: url)
            }
        }
    }

    // MARK: 文件操作

    func createFolder(named name: String) {
        do {
            let url = try FileService.createFolder(in: directory, named: name)
            showToast(L10n.created(url.lastPathComponent))
            reload()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    func rename(_ url: URL, to newName: String) {
        do {
            let newURL = try FileService.rename(url, to: newName)
            if newURL != url {
                MetadataStore.shared.forget(url)
                ArtworkStore.shared.remove(key: LibraryPaths.relativePath(of: url))
            }
            pruneStaleCaches()
            showToast(L10n.renamed(newURL.lastPathComponent))
            reload()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    @discardableResult
    func move(_ urls: [URL], to destination: URL) -> Bool {
        do {
            let count = try FileService.move(urls, to: destination)
            for url in urls {
                MetadataStore.shared.forget(url)
                ArtworkStore.shared.remove(key: LibraryPaths.relativePath(of: url))
                PlaybackProgress.shared.clear(LibraryPaths.relativePath(of: url))
            }
            pruneStaleCaches()
            showToast(count > 0 ? L10n.moved(count) : L10n.alreadyAtDestination)
            selection.removeAll()
            isEditing = false
            reload()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func delete(_ urls: [URL]) async -> Bool {
        guard !urls.isEmpty else { return false }
        let folderCount = urls.filter(FileService.isDirectory).count
        let fileCount = urls.count - folderCount
        let deletedFolderPaths = urls
            .filter(FileService.isDirectory)
            .map { LibraryPaths.relativePath(of: $0) }

        let errorMessage: String? = await Task.detached(priority: .userInitiated) {
            do {
                try FileService.delete(urls)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        if let errorMessage {
            showToast(errorMessage)
            return false
        }

        for url in urls {
            MetadataStore.shared.forget(url)
            ArtworkStore.shared.remove(key: LibraryPaths.relativePath(of: url))
            PlaybackProgress.shared.clear(LibraryPaths.relativePath(of: url))
        }
        for folderPath in deletedFolderPaths {
            PlaybackProgress.shared.clearDescendants(of: folderPath)
        }
        removeFromSnapshot(urls)
        // 播放进度已在上面按被删文件夹路径精确清理；这里只清理剩余缓存。
        pruneStaleCaches()
        showToast(deleteMessage(for: urls, folderCount: folderCount, fileCount: fileCount))
        selection.removeAll()
        isEditing = false
        reload()
        return true
    }

    /// 单个说名字；多选按文件夹和文件数量汇总。
    private func deleteMessage(
        for urls: [URL],
        folderCount: Int,
        fileCount: Int
    ) -> String {
        if urls.count == 1 {
            return L10n.deleted(urls[0].lastPathComponent)
        }
        if folderCount > 0, fileCount > 0 {
            return L10n.deletedMixed(folders: folderCount, files: fileCount)
        }
        if folderCount > 0 { return L10n.deletedFolders(folderCount) }
        return L10n.deletedFiles(fileCount)
    }

    func info(for url: URL) -> String {
        let isDir = FileService.isDirectory(url)
        var lines = [url.lastPathComponent]
        lines.append(FileService.formattedSize(FileService.size(of: url)))
        if isDir {
            lines.append(L10n.items(FileService.itemCount(of: url)))
        } else if let record = MetadataStore.shared.cached(for: url) {
            if !record.title.isEmpty { lines.append(L10n.titleInfo(record.title)) }
            if !record.artist.isEmpty { lines.append(L10n.artistInfo(record.artist)) }
            if !record.album.isEmpty { lines.append(L10n.albumInfo(record.album)) }
            if record.duration > 0 { lines.append(L10n.durationInfo(fmtTime(record.duration))) }
        }
        lines.append(LibraryPaths.relativePath(of: url))
        return lines.joined(separator: "\n")
    }

    /// 文件系统变了就重扫，同时清掉已经不存在文件的缓存。
    /// 从后台回来时先清空旧快照，避免已删除的文件夹短暂闪一下。
    func reload(clearingStale: Bool = false) {
        let token = beginLoad()
        if clearingStale {
            folders.removeAll()
            music.removeAll()
            others.removeAll()
            selection.removeAll()
        }
        Task { await load(token: token) }
    }

    /// 删除成功后先移除准确的行，避免编辑模式切换和异步重扫造成错误的列表动画。
    private func removeFromSnapshot(_ urls: [URL]) {
        let deletedPaths = Set(urls.map { $0.standardizedFileURL.path })
        folders.removeAll { deletedPaths.contains($0.id) }
        music.removeAll {
            deletedPaths.contains($0.url.standardizedFileURL.path)
        }
        others.removeAll {
            deletedPaths.contains($0.url.standardizedFileURL.path)
        }
    }

    /// 清掉不再对应任何现存音频的标签、封面和播放进度缓存。
    private func pruneStaleCaches() {
        let alive = Set(
            FileService.allAudioURLs().map { LibraryPaths.relativePath(of: $0) }
        )
        MetadataStore.shared.prune(existing: alive)
        ArtworkStore.shared.purgeOrphans(keeping: alive)
    }

    // MARK: 选择

    func toggleEditing() {
        isEditing.toggle()
        selection.removeAll()
    }

    func toggleSelection(_ url: URL) {
        let key = url.standardizedFileURL.path
        if selection.contains(key) { selection.remove(key) } else { selection.insert(key) }
    }

    // MARK: 提示

    func showToast(_ text: String) {
        ToastCenter.shared.show(text)
    }
}
