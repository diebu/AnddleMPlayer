import Foundation
import Observation

@MainActor
@Observable
final class MetadataStore {
    static let shared = MetadataStore()

    private var records: [String: MetadataRecord] = [:]
    private var inFlight = Set<String>()
    private var loadedFromDisk = false
    private var saveTask: Task<Void, Never>?

    private init() {}

    /// 命中且未过期才返回
    func cached(for url: URL) -> MetadataRecord? {
        loadFromDiskIfNeeded()
        let key = LibraryPaths.relativePath(of: url)
        guard let record = records[key] else { return nil }
        guard let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            return nil
        }
        let size = Int64(attrs.fileSize ?? -1)
        let modified = (attrs.contentModificationDate ?? .distantPast).timeIntervalSince1970
        guard size == record.size, abs(modified - record.modified) < 1 else { return nil }
        return record
    }

    func musicFile(for url: URL) -> MusicFile {
        var file = MusicFile(relativePath: LibraryPaths.relativePath(of: url), name: url.lastPathComponent)
        if let record = cached(for: url) {
            file.title = record.title
            file.artist = record.artist
            file.album = record.album
            file.duration = record.duration
            file.sizeBytes = record.size
            file.artworkKey = record.artwork
        }
        return file
    }

    /// 没有缓存就现读一次并写回缓存
    @discardableResult
    func ensure(_ url: URL) async -> MetadataRecord? {
        if let hit = cached(for: url) { return hit }
        let key = LibraryPaths.relativePath(of: url)
        guard !inFlight.contains(key) else { return nil }
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let meta = await MetadataReader.read(url: url)
        var record = MetadataRecord(
            size: Int64(attrs?.fileSize ?? -1),
            modified: (attrs?.contentModificationDate ?? .distantPast).timeIntervalSince1970,
            title: meta.title,
            artist: meta.artist,
            album: meta.album,
            duration: meta.duration,
            artwork: nil
        )
        if let artwork = meta.artwork {
            record.artwork = ArtworkStore.shared.store(artwork, key: key)
        }
        records[key] = record
        scheduleSave()
        return record
    }

    func forget(_ url: URL) {
        records.removeValue(forKey: LibraryPaths.relativePath(of: url))
        scheduleSave()
    }

    /// 扫描完之后清掉已经不存在的条目和它们的封面
    func prune(existing: Set<String>) {
        let stale = records.keys.filter { !existing.contains($0) }
        guard !stale.isEmpty else { return }
        for key in stale {
            ArtworkStore.shared.remove(key: key)
            records.removeValue(forKey: key)
        }
        scheduleSave()
    }

    private func loadFromDiskIfNeeded() {
        guard !loadedFromDisk else { return }
        loadedFromDisk = true
        guard let data = try? Data(contentsOf: LibraryPaths.metadataFile),
              let saved = try? JSONDecoder().decode([String: MetadataRecord].self, from: data) else { return }
        records = saved
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
        }
    }

    private func saveNow() {
        do {
            try FileManager.default.createDirectory(at: LibraryPaths.supportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(to: LibraryPaths.metadataFile, options: .atomic)
        } catch {
            // 写缓存失败不影响播放
        }
    }
}
