import SwiftUI

/// 选择移动目标：从 Documents 根目录开始逐层往下挑
struct MoveDestinationView: View {
    @Environment(AppearanceStore.self) private var appearance
    var onPick: (URL) -> Void
    var onCancel: () -> Void

    @State private var stack: [URL] = [LibraryPaths.root]
    @State private var folders: [FolderItem] = []

    private var current: URL { stack.last ?? LibraryPaths.root }

    var body: some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    Text("这个文件夹里没有子文件夹")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Palette.background)
                        .listRowSeparator(.hidden)
                }
                ForEach(folders) { folder in
                    Button {
                        stack.append(folder.url)
                    } label: {
                        FolderRowView(item: folder)
                    }
                    .buttonStyle(.plain)
                    .modifier(RowChrome())
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(stack.count > 1 ? current.lastPathComponent : L10n.chooseDestination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if stack.count > 1 {
                        Button {
                            stack.removeLast()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .foregroundStyle(appearance.accent)
                    } else {
                        Button("取消") { onCancel() }
                            .foregroundStyle(appearance.accent)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("移动到此处") { onPick(current) }
                        .foregroundStyle(appearance.accent)
                        .fontWeight(.medium)
                }
            }
            .task(id: current) {
                folders = FileService.children(of: current)
                    .filter { FileService.isDirectory($0) }
                    .map { url in
                        let summary = FileService.summary(of: url)
                        return FolderItem(
                            url: url,
                            folderCount: summary.folders,
                            fileCount: summary.files,
                            modified: summary.modified
                        )
                    }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
        }
        .presentationDetents([.large])
    }
}
