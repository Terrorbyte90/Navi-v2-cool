#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

// MARK: - iOS Sidebar (Master-chat-centric: chat history + quick panel access)

struct ChatHistorySidebar: View {
    @Binding var showSidebar: Bool
    @Binding var showNewProject: Bool
    @Binding var selectedTab: AppTab

    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var statusBroadcaster = DeviceStatusBroadcaster.shared
    @StateObject private var panelManager = FloatingPanelManager.shared

    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showOpenProject = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().overlay(
                LinearGradient(
                    colors: [Color.naviCyan.opacity(0.3), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ).frame(height: 0.5)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    quickActions
                    Divider().opacity(0.06).padding(.vertical, 8)
                    chatHistory
                }
                .padding(.bottom, 16)
            }

            Spacer(minLength: 0)
            Divider().opacity(0.08)

            // Project compact selector
            projectSection

            Divider().opacity(0.08)
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sidebarBackground)
        .ignoresSafeArea(edges: .vertical)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showOpenProject) {
            iCloudProjectPicker { url in openProjectFromURL(url) }
        }
    }

    // MARK: - Top bar

    var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    NaviOrb(size: 22, isActive: chatManager.isStreaming)
                    Text("Navi")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    _ = chatManager.newConversation()
                    showSidebar = false
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, topSafeArea + 8)
            .padding(.bottom, 10)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.5))
                TextField("Sök chattar…", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.surfaceHover, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Quick Actions (open floating panels)

    var quickActions: some View {
        VStack(alignment: .leading, spacing: 2) {
            quickActionItem(icon: "folder.fill", label: "Projekt", color: .naviCyan, panel: .project)
            quickActionItem(icon: "map.fill", label: "Planera", color: .naviMagenta, panel: .plan)
            quickActionItem(icon: "globe", label: "Webb", color: .naviViolet, panel: .browser)
            quickActionItem(icon: "cpu.fill", label: "Agenter", color: .orange, panel: .agents)
            quickActionItem(icon: "arrow.triangle.branch", label: "GitHub", color: .white, panel: .github)
            quickActionItem(icon: "photo.stack.fill", label: "Media", color: .pink, panel: .media)

            Divider().opacity(0.06).padding(.vertical, 4)

            navButton(icon: "plus.rectangle.on.folder", label: "Nytt projekt") {
                showSidebar = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNewProject = true }
            }
            navButton(icon: "folder.badge.plus", label: "Öppna från iCloud") {
                showOpenProject = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func quickActionItem(icon: String, label: String, color: Color, panel: FloatingPanelType) -> some View {
        Button {
            panelManager.show(panel)
            showSidebar = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color.opacity(0.8))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func navButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat history

    var filteredChats: [ChatConversation] {
        searchText.isEmpty
            ? chatManager.conversations
            : chatManager.conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    @ViewBuilder
    var chatHistory: some View {
        if !filteredChats.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Chattar")
                ForEach(filteredChats) { conv in
                    chatRow(conv)
                }
            }
        } else if searchText.isEmpty {
            emptyHint(icon: "bubble.left.and.bubble.right", text: "Inga chattar ännu")
        }
    }

    @ViewBuilder
    private func chatRow(_ conv: ChatConversation) -> some View {
        Button {
            chatManager.activeConversation = conv
            showSidebar = false
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.title)
                        .font(.system(size: 14, weight: chatManager.activeConversation?.id == conv.id ? .semibold : .regular))
                        .foregroundColor(chatManager.activeConversation?.id == conv.id ? .white : .primary.opacity(0.8))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text("\(conv.messages.count) meddelanden")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))
                        if conv.totalCostSEK > 0 {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.3))
                            Text(CostCalculator.shared.formatSEK(conv.totalCostSEK))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                chatManager.activeConversation?.id == conv.id
                    ? Color.naviCyan.opacity(0.08) : Color.clear
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await chatManager.delete(conv) }
            } label: { Label("Radera", systemImage: "trash") }
        }
    }

    // MARK: - Project Section (compact)

    var projectSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("PROJEKT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.35))
                Spacer()
                Button {
                    showSidebar = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNewProject = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            ForEach(projectStore.projects.prefix(4)) { project in
                Button {
                    projectStore.activeProject = project
                    showSidebar = false
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(project.color.color)
                            .frame(width: 7, height: 7)
                        Text(project.name)
                            .font(.system(size: 12))
                            .foregroundColor(projectStore.activeProject?.id == project.id ? .white : .primary.opacity(0.7))
                            .lineLimit(1)
                        Spacer()
                        if projectStore.activeProject?.id == project.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9))
                                .foregroundColor(.naviCyan)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom bar

    var bottomBar: some View {
        HStack(spacing: 10) {
            NaviOrb(size: 24, isActive: false)

            VStack(alignment: .leading, spacing: 1) {
                Text("Navi")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusBroadcaster.remoteMacIsOnline ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(statusBroadcaster.remoteMacIsOnline
                         ? "Mac ansluten"
                         : "Offline")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .padding(.bottom, bottomSafeArea)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.35))
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 3)
    }

    @ViewBuilder
    private func emptyHint(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.secondary.opacity(0.15))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal, 16)
    }

    private func openProjectFromURL(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let name = url.lastPathComponent
        var project = NaviProject(name: name, rootPath: url.path, iCloudPath: url.path)
        project.localPath = url.path

        Task {
            await projectStore.save(project)
            await MainActor.run {
                projectStore.activeProject = project
                showSidebar = false
            }
        }
    }

    private var topSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 44
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - iCloud Document Picker

struct iCloudProjectPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

#endif
