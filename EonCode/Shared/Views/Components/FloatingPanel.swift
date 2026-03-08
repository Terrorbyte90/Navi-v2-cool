import SwiftUI

// MARK: - Floating Panel Type

enum FloatingPanelType: String, Identifiable, CaseIterable {
    case code
    case todo
    case browser
    case artifacts
    case plan
    case github
    case agents
    case media
    case settings
    case project

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .code:      return "chevron.left.forwardslash.chevron.right"
        case .todo:      return "checklist"
        case .browser:   return "globe"
        case .artifacts: return "tray.2.fill"
        case .plan:      return "map.fill"
        case .github:    return "arrow.triangle.branch"
        case .agents:    return "cpu.fill"
        case .media:     return "photo.stack.fill"
        case .settings:  return "gearshape.fill"
        case .project:   return "folder.fill"
        }
    }

    var label: String {
        switch self {
        case .code:      return "Kod"
        case .todo:      return "Att göra"
        case .browser:   return "Webb"
        case .artifacts: return "Artefakter"
        case .plan:      return "Plan"
        case .github:    return "GitHub"
        case .agents:    return "Agenter"
        case .media:     return "Media"
        case .settings:  return "Inställningar"
        case .project:   return "Projekt"
        }
    }

    var accentColor: Color {
        switch self {
        case .code:      return .naviCyan
        case .todo:      return .naviMint
        case .browser:   return .naviViolet
        case .artifacts: return .naviAmber
        case .plan:      return .naviMagenta
        case .github:    return .white
        case .agents:    return .orange
        case .media:     return .pink
        case .settings:  return .secondary
        case .project:   return .naviCyan
        }
    }
}

// MARK: - Floating Panel Manager

@MainActor
final class FloatingPanelManager: ObservableObject {
    static let shared = FloatingPanelManager()

    @Published var activePanel: FloatingPanelType?
    @Published var panelExpanded = false

    func show(_ panel: FloatingPanelType) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if activePanel == panel {
                activePanel = nil
                panelExpanded = false
            } else {
                activePanel = panel
                panelExpanded = true
            }
        }
    }

    func dismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            activePanel = nil
            panelExpanded = false
        }
    }
}

// MARK: - Floating Panel Container

struct FloatingPanelContainer<Content: View>: View {
    let panelType: FloatingPanelType
    let isPresented: Bool
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        if isPresented {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    VStack(spacing: 0) {
                        // Drag handle + header
                        panelHeader

                        Divider()
                            .overlay(
                                LinearGradient(
                                    colors: [panelType.accentColor.opacity(0.6), panelType.accentColor.opacity(0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 0.5)

                        // Panel content
                        content()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: geo.size.height * 0.7)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                panelType.accentColor.opacity(0.3),
                                                Color.glassBorder.opacity(0.2),
                                                panelType.accentColor.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                            .shadow(color: panelType.accentColor.opacity(0.15), radius: 30, y: -5)
                            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .offset(y: dragOffset)
                    .offset(y: appeared ? 0 : geo.size.height * 0.5)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height * 0.5
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 100 {
                                    onDismiss()
                                }
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                    )
                }
                .padding(.horizontal, geo.size.width > 700 ? geo.size.width * 0.15 : 8)
                .padding(.bottom, 8)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            ))
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
            .onDisappear { appeared = false }
        }
    }

    private var panelHeader: some View {
        VStack(spacing: 8) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack(spacing: 10) {
                // Icon with accent glow
                ZStack {
                    Circle()
                        .fill(panelType.accentColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: panelType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(panelType.accentColor)
                }

                Text(panelType.label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Quick Action Dock (floating toolbar)

struct QuickActionDock: View {
    @ObservedObject var panelManager = FloatingPanelManager.shared
    @StateObject private var agentRunner = AutonomousAgentRunner.shared

    private let dockItems: [FloatingPanelType] = [
        .project, .code, .todo, .plan, .browser, .github, .agents, .media
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(dockItems) { item in
                    dockButton(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.glassBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
        .padding(.horizontal, 16)
    }

    private func dockButton(_ item: FloatingPanelType) -> some View {
        let isActive = panelManager.activePanel == item
        let hasActivity = item == .agents && !agentRunner.agents.filter({ $0.status.isActive }).isEmpty

        return Button { panelManager.show(item) } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isActive ? item.accentColor : .secondary)
                        .frame(width: 36, height: 28)

                    if hasActivity {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: -2)
                    }
                }

                Text(item.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isActive ? item.accentColor : .secondary.opacity(0.7))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? item.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("FloatingPanel") {
    ZStack {
        Color.masterBackground.ignoresSafeArea()
        AnimatedMeshBackground()

        FloatingPanelContainer(
            panelType: .code,
            isPresented: true,
            onDismiss: {}
        ) {
            VStack {
                Text("Code content here")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
        }
    }
}

#Preview("QuickActionDock") {
    ZStack {
        Color.masterBackground.ignoresSafeArea()
        VStack {
            Spacer()
            QuickActionDock()
                .padding(.bottom, 80)
        }
    }
}
