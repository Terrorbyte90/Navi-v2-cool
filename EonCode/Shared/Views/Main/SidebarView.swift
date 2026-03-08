import SwiftUI

// MARK: - SidebarView
// Redesigned: Chat-centric sidebar. Shows chat history, active project context,
// and quick-access buttons that open floating panels.

struct SidebarView: View {
    @Binding var selectedProject: NaviProject?
    @Binding var showNewProject: Bool
    @Binding var section: AppSection

    @StateObject private var store = ProjectStore.shared
    @StateObject private var agentPool = AgentPool.shared
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var statusBroadcaster = DeviceStatusBroadcaster.shared
    @StateObject private var panelManager = FloatingPanelManager.shared

    @State private var searchText = ""
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            searchBar
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            Divider().overlay(
                LinearGradient(
                    colors: [Color.naviCyan.opacity(0.3), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ).frame(height: 0.5)

            // Quick action buttons
            quickActions
                .padding(.top, 6)

            Divider().opacity(0.08).padding(.vertical, 6)

            // Chat history
            chatList

            Spacer(minLength: 0)
            Divider().opacity(0.1)

            // Project selector
            projectSection

            Divider().opacity(0.08)
            bottomBar
        }
        .frame(maxHeight: .infinity)
        .background(Color.sidebarBackground)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(width: 560, height: 640)
        }
    }

    // MARK: - Header

    var sidebarHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                NaviOrb(size: 22, isActive: chatManager.isStreaming)
                Text("Navi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.leading, 14)

            Spacer()

            Button { _ = chatManager.newConversation() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Ny chatt")
            .padding(.trailing, 8)
        }
        .frame(height: 46)
    }

    // MARK: - Search

    var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.5))
            TextField("Sök chattar…", text: $searchText)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(7)
    }

    // MARK: - Quick Actions (open floating panels)

    var quickActions: some View {
        VStack(alignment: .leading, spacing: 1) {
            quickActionItem(icon: "folder.fill", label: "Projekt", color: .naviCyan, panel: .project,
                            badge: store.projects.isEmpty ? nil : "\(store.projects.count)")
            quickActionItem(icon: "chevron.left.forwardslash.chevron.right", label: "Kod", color: .naviCyan, panel: .code)
            quickActionItem(icon: "map.fill", label: "Planera", color: .naviMagenta, panel: .plan)
            quickActionItem(icon: "globe", label: "Webb", color: .naviViolet, panel: .browser)
            quickActionItem(icon: "arrow.triangle.branch", label: "GitHub", color: .white, panel: .github)
            quickActionItem(icon: "cpu.fill", label: "Agenter", color: .orange, panel: .agents,
                            badge: {
                                let n = AutonomousAgentRunner.shared.agents.filter { $0.status.isActive }.count
                                return n > 0 ? "\(n)" : nil
                            }())
            quickActionItem(icon: "photo.stack.fill", label: "Media", color: .pink, panel: .media)
        }
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func quickActionItem(icon: String, label: String, color: Color, panel: FloatingPanelType, badge: String? = nil) -> some View {
        let isActive = panelManager.activePanel == panel
        Button { panelManager.show(panel) } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? color : .secondary.opacity(0.7))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : .primary.opacity(0.8))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat List

    var filteredChats: [ChatConversation] {
        searchText.isEmpty ? chatManager.conversations
            : chatManager.conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var chatList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if !filteredChats.isEmpty {
                    listSectionHeader("Chattar")
                    ForEach(filteredChats) { conv in
                        ChatConversationRow(
                            conversation: conv,
                            isSelected: chatManager.activeConversation?.id == conv.id,
                            onSelect: { chatManager.activeConversation = conv }
                        )
                    }
                } else {
                    emptyHint(icon: "bubble.left.and.bubble.right",
                              text: searchText.isEmpty ? "Inga chattar" : "Inga träffar")
                }
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Project Section (compact)

    var projectSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("PROJEKT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.4))
                Spacer()
                Button { showNewProject = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            if store.projects.isEmpty {
                Text("Inga projekt")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.3))
                    .padding(.horizontal, 14)
            } else {
                ForEach(store.projects.prefix(4)) { project in
                    Button { selectedProject = project } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(project.color.color)
                                .frame(width: 7, height: 7)
                            Text(project.name)
                                .font(.system(size: 12))
                                .foregroundColor(selectedProject?.id == project.id ? .white : .primary.opacity(0.7))
                                .lineLimit(1)
                            Spacer()
                            if selectedProject?.id == project.id {
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
        }
        .padding(.vertical, 8)
    }

    // MARK: - Bottom Bar

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
                    Text(statusBroadcaster.remoteMacIsOnline ? "Mac ansluten" : "Offline")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Inställningar")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func listSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.35))
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 2)
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
        .padding(.top, 28)
    }
}

// MARK: - Chat Conversation Row

struct ChatConversationRow: View {
    let conversation: ChatConversation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(conversation.updatedAt.relativeString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.4))
                        if conversation.totalCostSEK > 0 {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.2))
                            Text(CostCalculator.shared.formatSEK(conversation.totalCostSEK))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.35))
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.naviCyan.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .contextMenu {
            Button("Öppna", action: onSelect)
            Divider()
            Button("Radera", role: .destructive) {
                Task { await ChatManager.shared.delete(conversation) }
            }
        }
    }
}

struct SidebarSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.35))
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}

// MARK: - ProjectRow

struct ProjectRow: View {
    let project: NaviProject
    @Binding var selectedProject: NaviProject?
    @StateObject private var agentPool = AgentPool.shared

    private var isSelected: Bool { selectedProject?.id == project.id }
    private var agent: ProjectAgent? { agentPool.agents[project.id] }
    private var isRunning: Bool { agent?.isRunning ?? false }

    var body: some View {
        Button { selectedProject = project } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(project.color.color.opacity(0.85))
                        .frame(width: 9, height: 9)
                    if isRunning {
                        Circle()
                            .stroke(Color.green, lineWidth: 1.5)
                            .frame(width: 13, height: 13)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    if isRunning, let status = agent?.currentStatus, !status.isEmpty {
                        Text(status.prefix(28))
                            .font(.system(size: 10))
                            .foregroundColor(.green.opacity(0.8))
                            .lineLimit(1)
                    } else {
                        Text(project.modifiedAt.relativeString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                }

                Spacer()
                if isRunning { ProgressView().scaleEffect(0.55) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.naviCyan.opacity(0.08) : Color.clear))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .contextMenu {
            Button("Öppna") { selectedProject = project }
            Button(project.isFavorite ? "Ta bort favorit" : "Markera som favorit") {
                var u = project; u.isFavorite.toggle()
                Task { await ProjectStore.shared.save(u) }
            }
            Divider()
            Button("Ta bort", role: .destructive) {
                Task { await ProjectStore.shared.delete(project) }
            }
        }
    }
}

// MARK: - Preview

#Preview("SidebarView") {
    SidebarView(
        selectedProject: .constant(nil),
        showNewProject: .constant(false),
        section: .constant(.pureChat)
    )
    .frame(width: 260, height: 700)
}
