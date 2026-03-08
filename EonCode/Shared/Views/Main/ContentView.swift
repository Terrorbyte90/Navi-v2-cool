import SwiftUI

// MARK: - App Section (kept for orchestrator compatibility)

enum AppSection: String, Hashable { case project, pureChat, browser, artifacts, planning, github, agents, media }

// MARK: - App Tab (kept for iOS sidebar compatibility)

enum AppTab: Int, Hashable {
    case chat, project, browser, artifacts, plan, github, agents, media
}

// MARK: - ContentView (Master Chat Centric)
// The entire app revolves around the master chat.
// Everything else is a floating panel or sidebar history.

struct ContentView: View {
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var agentPool = AgentPool.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var statusBroadcaster = DeviceStatusBroadcaster.shared
    @StateObject private var panelManager = FloatingPanelManager.shared

    @State private var showSettings = false
    @State private var showNewProject = false

    var body: some View {
        #if os(macOS)
        macLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - macOS Layout (sidebar + master chat)

    #if os(macOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var macLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedProject: $projectStore.activeProject,
                showNewProject: $showNewProject,
                section: .constant(.pureChat)
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            MasterChatView()
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showNewProject) {
            NewProjectView()
        }
        .onAppear {
            BackgroundDaemon.shared.start()
            NaviOrchestrator.shared.setActiveView(.pureChat)
            NaviOrchestrator.shared.setActiveProject(projectStore.activeProject)
        }
        .onChange(of: projectStore.activeProject) { _, newProject in
            NaviOrchestrator.shared.setActiveProject(newProject)
        }
    }
    #endif

    // MARK: - iOS Layout (sidebar drawer + master chat)

    #if os(iOS)
    @State private var showSidebar = false
    @State private var selectedTab: AppTab = .chat
    @StateObject private var chatMgr = ChatManager.shared

    var iOSLayout: some View {
        ZStack(alignment: .leading) {
            // Main: Master Chat
            VStack(spacing: 0) {
                iOSTopBar
                Divider().overlay(
                    LinearGradient(
                        colors: [Color.naviCyan.opacity(0.3), Color.naviViolet.opacity(0.2), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ).frame(height: 0.5)

                MasterChatView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.masterBackground)

            // Dim overlay
            if showSidebar {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { closeSidebar() }
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Sidebar panel
            ChatHistorySidebar(
                showSidebar: $showSidebar,
                showNewProject: $showNewProject,
                selectedTab: $selectedTab
            )
            .frame(width: 300)
            .offset(x: showSidebar ? 0 : -300)
            .zIndex(11)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showSidebar)
        .sheet(isPresented: $showNewProject) { NewProjectView() }
        .onAppear {
            PeerSyncEngine.shared.startBrowsing()
            NaviOrchestrator.shared.setActiveView(.pureChat)
            NaviOrchestrator.shared.setActiveProject(projectStore.activeProject)
        }
        .onChange(of: projectStore.activeProject) { _, newProject in
            NaviOrchestrator.shared.setActiveProject(newProject)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didOpenGitHubProject)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                showSidebar = false
            }
        }
    }

    // iOS Top Bar - minimal, focused
    var iOSTopBar: some View {
        HStack(spacing: 0) {
            Button { openSidebar() } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Spacer()

            // Center: Navi title with model
            HStack(spacing: 5) {
                NaviOrb(size: 18, isActive: chatMgr.isStreaming)
                Text("Navi")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(chatMgr.activeConversation?.model.displayName ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(.naviCyan.opacity(0.7))
            }

            Spacer()

            // New chat
            Button { _ = chatMgr.newConversation() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 52)
        .background(Color.masterBackground.opacity(0.9))
    }

    private func openSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showSidebar = true
        }
    }

    private func closeSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showSidebar = false
        }
    }
    #endif
}

// MARK: - macOS Editor Tab (kept for compatibility)

enum MacEditorTab: Int, Hashable { case editor, agents }

#if os(macOS)
struct MacTabPill: View {
    let title: String
    let icon: String
    let tab: MacEditorTab
    @Binding var selected: MacEditorTab

    var isSelected: Bool { selected == tab }

    var body: some View {
        Button { selected = tab } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let tab: MacEditorTab
    @Binding var selected: MacEditorTab

    var isSelected: Bool { selected == tab }

    var body: some View {
        MacTabPill(title: title, icon: icon, tab: tab, selected: $selected)
    }
}
#endif

// MARK: - iOS file tree + editor (kept for compatibility)

#if os(iOS)
struct FileTreeAndEditorView: View {
    let project: NaviProject
    @State private var selectedNode: FileNode?
    @State private var fileContent = ""

    var body: some View {
        HSplitOrStack {
            FileTreeView(project: project, selectedNode: $selectedNode)
                .frame(maxWidth: 260)

            if let node = selectedNode, !node.isDirectory {
                CodeEditorView(
                    content: $fileContent,
                    fileType: node.fileType,
                    onSave: { newContent in
                        try? newContent.write(toFile: node.path, atomically: true, encoding: .utf8)
                    }
                )
                .onAppear {
                    fileContent = (try? String(contentsOfFile: node.path)) ?? ""
                }
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Välj en fil")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(selectedNode?.name ?? project.name)
    }
}

struct HSplitOrStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder let content: () -> Content

    var body: some View {
        if sizeClass == .regular {
            HStack(spacing: 0) { content() }
        } else {
            content()
        }
    }
}
#endif

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var showNewProject: Bool
    @StateObject private var store = ProjectStore.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                NaviOrb(size: 64, isActive: true)

                Text("Navi")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .naviCyan.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("AI-driven master-agent")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            if store.projects.isEmpty {
                VStack(spacing: 16) {
                    GlassButton("Skapa nytt projekt", icon: "plus", isPrimary: true) {
                        showNewProject = true
                    }
                    Text("Eller börja chatta direkt med Navi")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Senaste projekt")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    ForEach(store.projects.prefix(5)) { project in
                        Button {
                            store.activeProject = project
                        } label: {
                            HStack {
                                Circle()
                                    .fill(project.color.color)
                                    .frame(width: 10, height: 10)
                                Text(project.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(project.modifiedAt.relativeString)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.glassSurface))
                        }
                        .buttonStyle(.plain)
                    }

                    GlassButton("Nytt projekt", icon: "plus") {
                        showNewProject = true
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: 400)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.masterBackground)
    }
}

// MARK: - New Project View

struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = ProjectStore.shared

    @State private var name = ""
    @State private var projectType = "swift"
    @State private var useICloud = true
    @State private var isCreating = false

    let projectTypes = ["swift", "python", "node", "generic"]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                GlassTextField(placeholder: "Projektnamn", text: $name)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Projekttyp")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Picker("Typ", selection: $projectType) {
                        ForEach(projectTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Spara i iCloud Drive", isOn: $useICloud)
                    .toggleStyle(.switch)

                Spacer()

                GlassButton("Skapa projekt", icon: "plus", isPrimary: true) {
                    Task { await createProject() }
                }
                .disabled(name.isBlank || isCreating)
            }
            .padding()
            .navigationTitle("Nytt projekt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            #endif
        }
        .background(Color.masterBackground)
    }

    private func createProject() async {
        isCreating = true
        defer { isCreating = false }

        let baseURL: URL
        if useICloud, let icloudRoot = iCloudSyncEngine.shared.projectsRoot {
            baseURL = icloudRoot
        } else {
            #if os(macOS)
            baseURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Navi/Projects")
            #else
            baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Navi/Projects")
            #endif
        }

        let project = await store.create(name: name, at: baseURL.appendingPathComponent(name))

        #if os(macOS)
        if let url = project.resolvedURL {
            try? await FileSystemAgent.shared.createNewProject(
                name: name,
                type: FileSystemAgent.ProjectType(rawValue: projectType) ?? .generic,
                at: url.deletingLastPathComponent()
            )
        }
        #endif

        store.activeProject = project
        dismiss()
    }
}

// MARK: - Previews

#Preview("WelcomeView") {
    WelcomeView(showNewProject: .constant(false))
}

#Preview("NewProjectView") {
    NewProjectView()
}
