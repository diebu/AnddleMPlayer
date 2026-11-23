import Foundation

/// 记录上次从其他 App 导入文件时所在的目录。
enum RecentImportDirectory {
    private static let key = "recentImportDirectoryBookmark"

    static func save(_ directory: URL) {
        let accessed = directory.startAccessingSecurityScopedResource()
        defer {
            if accessed { directory.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? directory.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func restore() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let directory = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
        if stale { save(directory) }
        return directory
    }
}
