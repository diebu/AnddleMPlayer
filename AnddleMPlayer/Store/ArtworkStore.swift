import UIKit

/// 封面缓存：把内嵌封面压成 JPEG 存进 Caches/Artwork，内存里再缓存一层。
@MainActor
final class ArtworkStore {
    static let shared = ArtworkStore()

    private let memory = NSCache<NSString, UIImage>()
    private var knownMissing = Set<String>()

    private init() {
        memory.countLimit = 160
    }

    func image(for key: String?) -> UIImage? {
        guard let key, !key.isEmpty else { return nil }
        if let cached = memory.object(forKey: key as NSString) { return cached }
        if knownMissing.contains(key) { return nil }

        let url = LibraryPaths.artworkDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            knownMissing.insert(key)
            return nil
        }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    /// 保存封面并返回缓存文件名。key 用相对路径的哈希，
    /// 文件改名或移动之后 key 变了，旧封面自然不会再被引用。
    func store(_ data: Data, key: String) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = image.resized(maxSide: 1024)
        guard let jpeg = resized.jpegData(compressionQuality: 0.86) else { return nil }

        let name = Self.fileName(for: key)
        let url = LibraryPaths.artworkDirectory.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: LibraryPaths.artworkDirectory, withIntermediateDirectories: true)
            try jpeg.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        memory.setObject(resized, forKey: name as NSString)
        knownMissing.remove(name)
        return name
    }

    func remove(key: String?) {
        guard let key, !key.isEmpty else { return }
        let name = Self.fileName(for: key)
        memory.removeObject(forKey: name as NSString)
        knownMissing.remove(name)
        try? FileManager.default.removeItem(at: LibraryPaths.artworkDirectory.appendingPathComponent(name))
    }

    /// 清掉没有任何歌曲引用的封面文件
    func purgeOrphans(keeping keys: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: LibraryPaths.artworkDirectory, includingPropertiesForKeys: nil
        ) else { return }
        let alive = Set(keys.map { Self.fileName(for: $0) })
        for file in files where !alive.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func fileName(for key: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16) + ".jpg"
    }
}
