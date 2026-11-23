import SwiftUI
import UniformTypeIdentifiers

/// 一个目录的界面：浏览 + 增删改查。只显示这一层，不聚合、不递归。
struct DirectoryView: View {
    @Environment(AudioPlayer.self) private var player
    @Environment(AppState.self) private var appState
    @Environment(AppearanceStore.self) private var appearance
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: DirectoryModel
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var showRename = false
    @State private var renameTarget: URL?
    @State private var renameText = ""
    @State private var showMove = false
    @State private var moveTargets: [URL] = []
    @State private var showInfo = false
    @State private var infoText = ""
    @State private var presenter = DocumentPickerPresenter()
    @State private var isChoosingImportFiles = false
    @State private var isImporting = false
    @State private var isDeleting = false
    @State private var showsDeletionProgress = false
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var selectionDragAnchor: String?
    @State private var selectionDragMode: SelectionDragMode?
    @State private var selectionDidDrag = false

    init(directory: URL, isRoot: Bool) {
        _model = State(initialValue: DirectoryModel(directory: directory, isRoot: isRoot))
    }

    private var isRoot: Bool { model.isRoot }
    private var title: String { isRoot ? L10n.music : model.directory.lastPathComponent }

    var body: some View {
        List {
            ForEach(model.folders) { folder in
                folderRow(folder)
            }

            if !model.folders.isEmpty && (!model.music.isEmpty || !model.others.isEmpty) {
                dividerRow
            }

            ForEach(model.music) { file in
                musicRow(file)
            }

            ForEach(model.others) { item in
                otherRow(item)
            }

            if model.loading && model.isEmpty {
                messageRow(icon: nil, title: "正在读取…", detail: nil)
            } else if model.isEmpty {
                messageRow(
                    icon: "music.note.list",
                    title: "这个文件夹是空的",
                    detail: "可以从其他 App 导入音乐，\n也可以从「文件」App、Finder 拖入。",
                    actionTitle: "从其他 App 导入…",
                    action: { startOtherAppImport() }
                )
            }
        }
        .overlay {
            if isImporting {
                BulkFileOperationOverlay(
                    title: L10n.key("正在导入…"),
                    symbol: "arrow.down.doc.fill"
                )
                .transition(.opacity)
            } else if isDeleting, showsDeletionProgress {
                BulkFileOperationOverlay(
                    title: L10n.key("正在删除…"),
                    symbol: "trash.fill"
                )
                .transition(.opacity)
            }
        }
        .onPreferenceChange(DirectoryRowFrameKey.self) {
            rowFrames = $0
        }
        .listStyle(.plain)
        // 根视图底部的迷你播放器属于外层安全区，列表自身再留出同等高度，
        // 确保最后一行能完整滚到播放器上方，而不是被盖住。
        .contentMargins(
            .bottom,
            player.current != nil && !appState.isEditing ? 64 : 0,
            for: .scrollContent
        )
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .environment(\.defaultMinListRowHeight, 1)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if appState.isEditing { editToolbar }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        // 从别的 App 回来（比如刚在「文件」里拖了歌）自动重扫，省得手动下拉
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active, oldPhase != .active {
                model.reload(clearingStale: true)
            }
        }
        // 自动播完一首并切到下一首时，重新读取当前目录，
        // 让列表里的当前行、播放进度和文件状态立即刷新。
        .onChange(of: player.current?.id) { oldID, newID in
            if oldID != newID { model.reload() }
        }
        .onChange(of: appState.libraryVersion) { _, _ in model.reload() }
        .onAppear {
            if isRoot { appState.isEditing = false }
        }
        .onChange(of: appState.isEditing) { _, editing in
            model.isEditing = editing
            if !editing {
                model.selection.removeAll()
                selectionDragAnchor = nil
                selectionDragMode = nil
                selectionDidDrag = false
                rowFrames.removeAll()
            }
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("创建") {
                model.createFolder(named: newFolderName)
                newFolderName = ""
            }
            Button("取消", role: .cancel) { newFolderName = "" }
        }
        .alert("重命名", isPresented: $showRename) {
            TextField("新名称", text: $renameText)
            Button("确定") {
                if let target = renameTarget { model.rename(target, to: renameText) }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        }
        .alert("简介", isPresented: $showInfo) {
            Button("好") {}
        } message: {
            Text(infoText)
        }
        .sheet(isPresented: $showMove) {
            MoveDestinationView { destination in
                if model.move(moveTargets, to: destination) {
                    appState.isEditing = false
                }
                moveTargets = []
                showMove = false
            } onCancel: {
                moveTargets = []
                showMove = false
            }
        }
    }

    // MARK: 行

    @ViewBuilder
    private func folderRow(_ folder: FolderItem) -> some View {
        if appState.isEditing {
            FolderRowView(item: folder, isEditing: true, isSelected: isSelected(folder.url))
                .contentShape(Rectangle())
                .onTapGesture { toggleSelectionForRow(folder.url) }
                .accessibilityAddTraits(.isButton)
                .overlay(alignment: .leading) {
                    selectionDragArea(for: folder.url)
                }
            .modifier(RowChrome())
            .background(DirectoryRowFrameReader(url: folder.url))
        } else {
            NavigationLink(value: folder.url) {
                FolderRowView(item: folder)
            }
            .modifier(RowChrome())
            .contextMenu { menu(for: folder.url, isFolder: true) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteSwipe([folder.url])
            }
        }
    }

    @ViewBuilder
    private func musicRow(_ file: MusicFile) -> some View {
        let isCurrent = player.current?.id == file.id
        if appState.isEditing {
            MusicRowView(file: file, isCurrent: isCurrent, isPlaying: false,
                         isEditing: true, isSelected: isSelected(file.url))
                .contentShape(Rectangle())
                .onTapGesture { toggleSelectionForRow(file.url) }
                .accessibilityAddTraits(.isButton)
                .overlay(alignment: .leading) {
                    selectionDragArea(for: file.url)
                }
            .modifier(RowChrome())
            .background(DirectoryRowFrameReader(url: file.url))
        } else {
            Button {
                play(file)
            } label: {
                MusicRowView(file: file, isCurrent: isCurrent, isPlaying: player.isPlaying)
            }
            .buttonStyle(.plain)
            .modifier(RowChrome())
            .contextMenu { menu(for: file.url, isFolder: false, file: file) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteSwipe([file.url])
            }
        }
    }

    @ViewBuilder
    private func otherRow(_ item: OtherItem) -> some View {
        if appState.isEditing {
            OtherRowView(item: item, isEditing: true, isSelected: isSelected(item.url))
                .contentShape(Rectangle())
                .onTapGesture { toggleSelectionForRow(item.url) }
                .accessibilityAddTraits(.isButton)
                .overlay(alignment: .leading) {
                    selectionDragArea(for: item.url)
                }
            .modifier(RowChrome())
            .background(DirectoryRowFrameReader(url: item.url))
        } else {
            Button {
                showInfo(for: item.url)
            } label: {
                OtherRowView(item: item)
            }
            .buttonStyle(.plain)
            .modifier(RowChrome())
            .contextMenu { menu(for: item.url, isFolder: false) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteSwipe([item.url])
            }
        }
    }

    private var dividerRow: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 1)
            .listRowBackground(Palette.background)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
    }

    private func messageRow(
        icon: String?,
        title: String,
        detail: String?,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Palette.faint)
            }
            Text(LocalizedStringKey(title))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.text)
            if let detail {
                Text(LocalizedStringKey(detail))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(LocalizedStringKey(actionTitle))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.accentInk)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(appearance.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .listRowBackground(Palette.background)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
    }

    // MARK: 菜单

    @ViewBuilder
    private func menu(for url: URL, isFolder: Bool, file: MusicFile? = nil) -> some View {
        if isFolder {
            Button {
                playFolder(url)
            } label: {
                Label("播放全部", systemImage: "play.fill")
            }
        } else if let file {
            Button {
                play(file)
            } label: {
                Label("播放", systemImage: "play.fill")
            }
        }
        Button {
            beginRename(url)
        } label: {
            Label("重命名", systemImage: "pencil")
        }
        Button {
            moveTargets = [url]
            showMove = true
        } label: {
            Label("移动到…", systemImage: "folder")
        }
        Button {
            showInfo(for: url)
        } label: {
            Label("显示简介", systemImage: "info.circle")
        }
        Divider()
        Button(role: .destructive) {
            remove([url])
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private func deleteSwipe(_ urls: [URL]) -> some View {
        Button(role: .destructive) {
            remove(urls)
        } label: {
            Label("删除", systemImage: "trash")
        }
        .tint(appearance.dangerFill)
    }

    // MARK: 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if appState.isEditing {
                Button("取消") {
                    appState.isEditing = false
                }
                .foregroundStyle(appearance.accent)
                .fontWeight(.medium)
            } else if !model.isEmpty {
                Button("选择") {
                    appState.isEditing = true
                }
                .foregroundStyle(appearance.accent)
                .fontWeight(.medium)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if !appState.isEditing {
                Menu {
                    Button {
                        newFolderName = ""
                        showNewFolder = true
                    } label: {
                        Label("新建文件夹", systemImage: "folder.badge.plus")
                    }
                    Button {
                        startOtherAppImport()
                    } label: {
                        Label("从其他 App 导入…", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button {
                        model.reload()
                    } label: {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Palette.text)
                }
            }
        }
    }

    private var editToolbar: some View {
        HStack(spacing: 0) {
            Button {
                model.toggleSelectAll()
            } label: {
                Text(model.allSelected ? L10n.deselectAll : L10n.selectAll)
                    .foregroundStyle(appearance.accent)
            }
            .frame(maxWidth: .infinity)

            Button {
                moveTargets = model.selectedURLs
                if !moveTargets.isEmpty { showMove = true }
            } label: {
                HStack(spacing: 5) {
                    Text("移动")
                    // 选中几个就显示几个，没选时不显示
                    if model.selectedCount > 0 {
                        Text("\(model.selectedCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.accentInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(appearance.accent, in: Capsule())
                    }
                }
                .foregroundStyle(model.selectedCount > 0 ? appearance.accent : Palette.faint)
            }
            .disabled(model.selectedCount == 0)
            .frame(maxWidth: .infinity)

            Button("重命名") {
                if let url = model.selectedURLs.first { beginRename(url) }
            }
            .foregroundStyle(model.selectedCount == 1 ? appearance.accent : Palette.faint)
            .disabled(model.selectedCount != 1)
            .frame(maxWidth: .infinity)

            Button("删除") {
                remove(model.selectedURLs)
            }
            .foregroundStyle(model.selectedCount > 0 ? appearance.accent : Palette.faint)
            .frame(maxWidth: .infinity)
            .disabled(model.selectedCount == 0)
        }
        .font(.system(size: 14))
        .padding(.top, 15)
        .padding(.bottom, 8)
        .background(Palette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line).frame(height: 0.5)
        }
    }

    // MARK: 动作

    private func isSelected(_ url: URL) -> Bool {
        model.selection.contains(url.standardizedFileURL.path)
    }

    private func toggleSelectionForRow(_ url: URL) {
        guard !selectionDidDrag else { return }
        model.toggleSelection(url)
    }

    private func selectionDragArea(for url: URL) -> some View {
        Color.clear
            .frame(width: RowMetrics.columnWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { toggleSelectionForRow(url) }
            .gesture(selectionDragGesture(for: url))
            .accessibilityHidden(true)
    }

    private func selectionDragGesture(for url: URL) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard appState.isEditing else { return }
                selectionDidDrag = true

                let startPath = url.standardizedFileURL.path
                if selectionDragAnchor == nil {
                    selectionDragAnchor = startPath
                    selectionDragMode = isSelected(url) ? .deselect : .select
                    applySelectionDrag(from: startPath, to: startPath)
                }

                guard let anchor = selectionDragAnchor,
                      let target = selectionTarget(at: value.location.y) else {
                    return
                }
                applySelectionDrag(from: anchor, to: target)
            }
            .onEnded { _ in
                selectionDragAnchor = nil
                selectionDragMode = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    selectionDidDrag = false
                }
            }
    }

    private func selectionTarget(at y: CGFloat) -> String? {
        let frames = model.allURLs.compactMap { url -> (String, CGRect)? in
            let path = url.standardizedFileURL.path
            guard let frame = rowFrames[path] else { return nil }
            return (path, frame)
        }
        guard !frames.isEmpty else { return nil }

        if let direct = frames.first(where: { y >= $0.1.minY && y <= $0.1.maxY }) {
            return direct.0
        }
        return frames.min {
            abs($0.1.midY - y) < abs($1.1.midY - y)
        }?.0
    }

    private func applySelectionDrag(from anchor: String, to target: String) {
        guard let mode = selectionDragMode else { return }
        let paths = model.allURLs.map { $0.standardizedFileURL.path }
        guard let anchorIndex = paths.firstIndex(of: anchor),
              let targetIndex = paths.firstIndex(of: target) else {
            return
        }
        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        let changed = Set(paths[range])

        switch mode {
        case .select:
            model.selection.formUnion(changed)
        case .deselect:
            model.selection.subtract(changed)
        }
    }

    private func play(_ file: MusicFile) {
        if player.current?.id == file.id {
            player.toggle()
        } else {
            player.play(file, in: model.music)
        }
        appState.showNowPlaying = true
    }

    /// 文件夹的「播放全部」只排这一层的音频，子文件夹不参与
    private func playFolder(_ url: URL) {
        let files = FileService.audioURLs(in: url).map { MetadataStore.shared.musicFile(for: $0) }
        guard let first = files.first else {
            ToastCenter.shared.show(L10n.noAudioFiles)
            return
        }
        player.play(first, in: files)
    }

    private func beginRename(_ url: URL) {
        renameTarget = url
        renameText = url.lastPathComponent
        showRename = true
    }

    /// 列表里的删除是明确动作，直接执行，不再弹确认
    private func remove(_ urls: [URL]) {
        guard !urls.isEmpty, !isDeleting, !isImporting else { return }
        let showsProgress = urls.count > 1 || urls.contains(where: FileService.isDirectory)
        isDeleting = true
        if showsProgress {
            withAnimation(.easeInOut(duration: 0.16)) {
                showsDeletionProgress = true
            }
        }

        Task { @MainActor in
            let startedAt = Date()
            let deleted = await model.delete(urls)

            // 删除很快完成时也让动画完整显示一小段时间，避免一闪而过。
            if showsProgress {
                let minimumDuration = 0.45
                let elapsed = Date().timeIntervalSince(startedAt)
                if elapsed < minimumDuration {
                    try? await Task.sleep(
                        for: .seconds(minimumDuration - elapsed)
                    )
                }
            }

            withAnimation(.easeOut(duration: 0.16)) {
                showsDeletionProgress = false
            }
            isDeleting = false

            if deleted {
                if let current = player.current?.url.standardizedFileURL,
                   urls.contains(where: {
                       let deleted = $0.standardizedFileURL.path
                       return current.path == deleted || current.path.hasPrefix(deleted + "/")
                   }) {
                    // AVPlayer 会持有当前文件的句柄。关闭播放现场后，
                    // 已从磁盘删除的文件才会立即释放占用空间。
                    player.discardCurrentIfMissing()
                    appState.showNowPlaying = false
                }
                appState.isEditing = false
            }
        }
    }

    private func showInfo(for url: URL) {
        infoText = model.info(for: url)
        showInfo = true
    }

    // MARK: 从其他 App 导入

    private func startOtherAppImport() {
        guard !isChoosingImportFiles, !isImporting, !isDeleting else { return }
        isChoosingImportFiles = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            var contentTypes: [UTType] = [.folder]
            for ext in FileService.audioExtensions {
                if let type = UTType(filenameExtension: ext) {
                    contentTypes.append(type)
                }
            }
            presenter.present(
                contentTypes: Array(Set(contentTypes)),
                allowsMultipleSelection: true,
                initialDirectory: RecentImportDirectory.restore()
            ) { urls in
                isChoosingImportFiles = false
                guard !urls.isEmpty else { return }
                importLocalItems(urls)
            } onCancel: {
                isChoosingImportFiles = false
            }
        }
    }

    private func importLocalItems(_ urls: [URL]) {
        guard !isImporting, !isDeleting else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            isImporting = true
        }
        let destination = model.directory

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                FileService.importAudioItems(urls, into: destination)
            }.value

            withAnimation(.easeOut(duration: 0.16)) {
                isImporting = false
            }
            ToastCenter.shared.show(
                L10n.audioImportSummary(
                    imported: result.importedAudio,
                    skippedEmptyFolders: result.skippedEmptyFolders
                )
            )
            if result.importedAudio > 0 { model.reload() }
        }
    }

}

private enum SelectionDragMode {
    case select
    case deselect
}

private struct DirectoryRowFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(
        value: inout [String: CGRect],
        nextValue: () -> [String: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct DirectoryRowFrameReader: View {
    var url: URL

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: DirectoryRowFrameKey.self,
                value: [url.standardizedFileURL.path: proxy.frame(in: .global)]
            )
        }
    }
}

/// 导入、删除较多文件时的持续动画，避免只有静态转圈或界面像卡死。
private struct BulkFileOperationOverlay: View {
    @Environment(AppearanceStore.self) private var appearance
    var title: String
    var symbol: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 12) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let turn = time.truncatingRemainder(dividingBy: 1.15) / 1.15
                    let pulse = CGFloat(0.94 + 0.06 * ((sin(time * 4.2) + 1) / 2))

                    ZStack {
                        Circle()
                            .stroke(Palette.line, lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: 0.26)
                            .stroke(
                                appearance.accent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(turn * 360))
                        Circle()
                            .fill(appearance.accent.opacity(0.14))
                            .scaleEffect(pulse)
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(appearance.accent)
                    }
                    .frame(width: 52, height: 52)
                }

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.text)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .background(
                Palette.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.line, lineWidth: 0.5)
            }
        }
    }
}

/// 列表行的统一样式：黑底、底部一条极淡的分隔线、左右 20pt 内边距。
/// 分隔线不能没有 —— 纯黑底上每行会糊成一片，看不出边界。
struct RowChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Palette.background)
            .listRowSeparator(.visible, edges: .bottom)
            .listRowSeparatorTint(Color.white.opacity(0.08))
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            // 左边不留白：类型栏要贴着屏幕边缘，像文件管理器那样
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}
