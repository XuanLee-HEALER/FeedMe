//
//  FeedManagementView.swift
//  FeedMe
//
//  Created by Claude on 2026/2/3.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 通知名称

extension Notification.Name {
    static let feedDataDidChange = Notification.Name("feedDataDidChange")
}

/// 订阅源管理窗口
struct FeedManagementView: View {
    @State private var sources: [FeedSource] = []
    @State private var showingAddSheet = false
    @State private var selectedSources: Set<FeedSource.ID> = []  // 支持多选
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var importError: String?
    @State private var searchText = ""

    /// 过滤后的订阅源列表
    private var filteredSources: [FeedSource] {
        if searchText.isEmpty {
            return sources
        }
        return sources.filter { source in
            source.title.localizedCaseInsensitiveContains(searchText) ||
            source.feedURL.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if sources.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("还没有订阅任何 Feed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Button("添加订阅源") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("空列表，还没有订阅任何 Feed")
                    .accessibilityHint("点击添加订阅源按钮开始")
                } else {
                    List(selection: $selectedSources) {
                        ForEach(filteredSources) { source in
                            FeedSourceRow(source: source)
                                .tag(source.id)
                                .contextMenu {
                                    Button("删除", role: .destructive) {
                                        deleteSource(source)
                                    }
                                }
                                .accessibilityLabel("\(source.title)，\(source.isEnabled ? "已启用" : "已禁用")\(source.lastError != nil ? "，有错误" : "")")
                                .accessibilityHint("双击打开详情，右键删除")
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                deleteSource(filteredSources[index])
                            }
                        }
                    }
                    .clipped()
                }
            }
            .clipped()
            .navigationTitle("订阅源")
            .searchable(text: $searchText, prompt: "搜索订阅源")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加订阅源")
                    .keyboardShortcut("n", modifiers: .command)

                    Menu {
                        Button("导入 OPML…") {
                            showingImportPicker = true
                        }
                        .keyboardShortcut("i", modifiers: .command)

                        Button("导出 OPML…") {
                            showingExportPicker = true
                        }
                        .disabled(sources.isEmpty)
                        .keyboardShortcut("e", modifiers: .command)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多操作")
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        deleteSelectedSources()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedSources.isEmpty)
                    .accessibilityLabel("删除选中的订阅源")
                    .keyboardShortcut(.delete, modifiers: [])
                }
            }
        } detail: {
            if let sourceIndex = sources.firstIndex(where: { selectedSources.contains($0.id) }) {
                FeedSourceDetailView(
                    source: $sources[sourceIndex],
                    onSave: { updatedSource in
                        updateSource(updatedSource)
                    }
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("选择一个订阅源查看详情")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("未选择订阅源")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddFeedSheet { newSource in
                addSource(newSource)
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.xml, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: OPMLDocument(sources: sources),
            contentType: .xml,
            defaultFilename: "FeedMe-Subscriptions.opml"
        ) { result in
            if case .failure(let error) = result {
                print("Export failed: \(error)")
            }
        }
        .alert("导入失败", isPresented: .constant(importError != nil)) {
            Button("确定") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadSources()
        }
    }

    // MARK: - OPML 导入

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task { @MainActor in
                do {
                    // 获取文件访问权限
                    guard url.startAccessingSecurityScopedResource() else {
                        self.importError = "无法访问文件"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: url)
                    let importedSources = try OPMLService.shared.importOPML(from: data)

                    // 保存到数据库
                    for source in importedSources {
                        try? FeedStorage.shared.addSource(source)
                    }

                    self.loadSources()
                    print("Imported \(importedSources.count) sources")
                } catch {
                    self.importError = error.localizedDescription
                }
            }

        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    // MARK: - Actions

    private func loadSources() {
        do {
            sources = try FeedStorage.shared.fetchAllSources()
        } catch {
            print("Failed to load sources: \(error)")
        }
    }

    private func addSource(_ source: FeedSource) {
        do {
            try FeedStorage.shared.addSource(source)
            loadSources()
            // 添加后立即刷新获取文章
            Task { @MainActor in
                await FeedManager.shared.refresh(sourceId: source.id)
                self.loadSources()
                // 通知更新状态栏未读计数
                NotificationCenter.default.post(name: .feedDataDidChange, object: nil)
            }
        } catch {
            print("Failed to add source: \(error)")
        }
    }

    private func deleteSource(_ source: FeedSource) {
        do {
            try FeedStorage.shared.deleteSource(id: source.id)
            selectedSources.remove(source.id)
            loadSources()
            // 通知更新状态栏未读计数
            NotificationCenter.default.post(name: .feedDataDidChange, object: nil)
        } catch {
            print("Failed to delete source: \(error)")
        }
    }

    private func deleteSelectedSources() {
        let idsToDelete = selectedSources
        for id in idsToDelete {
            if let source = sources.first(where: { $0.id == id }) {
                deleteSource(source)
            }
        }
    }

    private func updateSource(_ source: FeedSource) {
        do {
            try FeedStorage.shared.updateSource(source)
            loadSources()
        } catch {
            print("Failed to update source: \(error)")
        }
    }
}

// MARK: - FeedSourceRow

struct FeedSourceRow: View {
    let source: FeedSource

    var body: some View {
        HStack {
            // 状态指示器
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(source.title)
                        .font(.headline)
                        .foregroundStyle(source.lastError != nil ? .red : .primary)

                    if source.lastError != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let error = source.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    Text(source.feedURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !source.isEnabled {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        if source.lastError != nil {
            return .red
        } else if !source.isEnabled {
            return .gray
        } else {
            return .green
        }
    }
}

// MARK: - FeedSourceDetailView (可编辑)

struct FeedSourceDetailView: View {
    @Binding var source: FeedSource
    let onSave: (FeedSource) -> Void

    // 本地编辑状态
    @State private var editedTitle: String = ""
    @State private var editedFeedURL: String = ""
    @State private var editedIsEnabled: Bool = true
    @State private var editedRefreshInterval: Int = 0

    // 自动保存任务
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("名称", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: editedTitle) {
                        scheduleSave()
                    }

                TextField("Feed URL", text: $editedFeedURL)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: editedFeedURL) {
                        scheduleSave()
                    }

                if let siteURL = source.siteURL, !siteURL.isEmpty {
                    LabeledContent("网站", value: siteURL)
                }
            }

            Section("设置") {
                Toggle("启用", isOn: $editedIsEnabled)
                    .onChange(of: editedIsEnabled) {
                        saveImmediately()
                    }

                Picker("刷新间隔", selection: $editedRefreshInterval) {
                    Text("使用全局设置").tag(0)
                    Text("5 分钟").tag(5)
                    Text("15 分钟").tag(15)
                    Text("30 分钟").tag(30)
                    Text("60 分钟").tag(60)
                }
                .onChange(of: editedRefreshInterval) {
                    saveImmediately()
                }
            }

            Section("状态") {
                if let lastFetched = source.lastFetchedAt {
                    LabeledContent("最后刷新", value: lastFetched.formatted())
                }
                if let error = source.lastError {
                    LabeledContent("错误") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                if source.consecutiveFailures > 0 {
                    LabeledContent("连续失败次数", value: "\(source.consecutiveFailures)")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            syncFromSource()
        }
        .onChange(of: source.id) {
            syncFromSource()
        }
    }

    /// 从 source 同步到本地编辑状态
    private func syncFromSource() {
        editedTitle = source.title
        editedFeedURL = source.feedURL
        editedIsEnabled = source.isEnabled
        editedRefreshInterval = source.refreshIntervalMinutes
    }

    /// 延迟保存（用于 TextField，防止频繁保存）
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
            guard !Task.isCancelled else { return }
            await MainActor.run {
                performSave()
            }
        }
    }

    /// 立即保存（用于 Toggle/Picker）
    private func saveImmediately() {
        saveTask?.cancel()
        performSave()
    }

    /// 执行保存
    private func performSave() {
        var updatedSource = source
        updatedSource.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedSource.feedURL = editedFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedSource.isEnabled = editedIsEnabled
        updatedSource.refreshIntervalMinutes = editedRefreshInterval

        // 验证数据有效性
        guard !updatedSource.title.isEmpty, !updatedSource.feedURL.isEmpty else {
            return
        }

        source = updatedSource
        onSave(updatedSource)
    }
}

// MARK: - AddFeedSheet

struct AddFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedURL = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    let onAdd: (FeedSource) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Feed URL 或站点 URL", text: $feedURL)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("添加订阅源")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addFeed()
                    }
                    .disabled(feedURL.isEmpty || isValidating)
                }
            }
        }
        .frame(width: 400, height: 200)
    }

    private func addFeed() {
        isValidating = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // 验证 URL
                guard URL(string: feedURL) != nil else {
                    self.errorMessage = "无效的 URL"
                    self.isValidating = false
                    return
                }

                // 尝试直接作为 Feed URL
                let isValid = try await FeedDiscovery.validateFeedURL(feedURL)

                if isValid {
                    // 直接添加
                    let source = FeedSource(
                        title: "新订阅源",
                        feedURL: feedURL
                    )
                    onAdd(source)
                    dismiss()
                } else {
                    // 尝试自动发现
                    let discovered = try await FeedDiscovery.discover(from: feedURL)

                    if let first = discovered.first {
                        let source = FeedSource(
                            title: first.title ?? "新订阅源",
                            siteURL: feedURL,
                            feedURL: first.url
                        )
                        onAdd(source)
                        dismiss()
                    } else {
                        self.errorMessage = "未找到 Feed"
                    }
                }

                self.isValidating = false

            } catch {
                self.errorMessage = error.localizedDescription
                self.isValidating = false
            }
        }
    }
}

// MARK: - OPML 文档（用于导出）

struct OPMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml] }

    let sources: [FeedSource]

    init(sources: [FeedSource]) {
        self.sources = sources
    }

    init(configuration: ReadConfiguration) throws {
        // 导出时不需要读取
        self.sources = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = OPMLService.shared.exportOPML(sources: sources)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    FeedManagementView()
}
