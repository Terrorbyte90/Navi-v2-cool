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
    @State private var glowPhase: CGFloat = 0

    var body: some View {
        if isPresented {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 50)

                    VStack(spacing: 0) {
                        // Drag handle + header
                        panelHeader

                        // Accent gradient divider with shimmer
                        ZStack {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            panelType.accentColor.opacity(0.0),
                                            panelType.accentColor.opacity(0.7),
                                            panelType.accentColor.opacity(0.9),
                                            panelType.accentColor.opacity(0.7),
                                            panelType.accentColor.opacity(0.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 1)

                            // Shimmer highlight
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: max(0, glowPhase - 0.15)),
                                            .init(color: .white.opacity(0.6), location: glowPhase),
                                            .init(color: .clear, location: min(1, glowPhase + 0.15))
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 1)
                        }

                        // Panel content
                        content()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: geo.size.height * 0.75)
                    .background(
                        ZStack {
                            // Deep glass
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)

                            // Subtle accent tint
                            RoundedRectangle(cornerRadius: 24)
                                .fill(panelType.accentColor.opacity(0.03))

                            // Vivid border
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            panelType.accentColor.opacity(0.5),
                                            Color.glassBorder.opacity(0.15),
                                            panelType.accentColor.opacity(0.2),
                                            Color.glassBorder.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: panelType.accentColor.opacity(0.2), radius: 40, y: -5)
                        .shadow(color: .black.opacity(0.6), radius: 25, y: 12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .scaleEffect(appeared ? 1.0 : 0.92)
                    .offset(y: dragOffset)
                    .offset(y: appeared ? 0 : geo.size.height * 0.4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height * 0.4
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
                .padding(.horizontal, geo.size.width > 700 ? geo.size.width * 0.12 : 6)
                .padding(.bottom, 6)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .move(edge: .bottom))
            ))
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    appeared = true
                }
                // Shimmer on entry
                withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                    glowPhase = 1.0
                }
            }
            .onDisappear {
                appeared = false
                glowPhase = 0
            }
        }
    }

    private var panelHeader: some View {
        VStack(spacing: 8) {
            // Drag indicator with glow
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [panelType.accentColor.opacity(0.3), .white.opacity(0.3), panelType.accentColor.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            HStack(spacing: 10) {
                // Icon with accent glow ring
                ZStack {
                    Circle()
                        .fill(panelType.accentColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Circle()
                        .strokeBorder(panelType.accentColor.opacity(0.25), lineWidth: 0.8)
                        .frame(width: 34, height: 34)
                    Image(systemName: panelType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(panelType.accentColor)
                        .shadow(color: panelType.accentColor.opacity(0.5), radius: 4)
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
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                        )
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
        .project, .code, .todo, .plan, .browser, .github, .agents, .media, .settings
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(dockItems) { item in
                    dockButton(item)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.masterBackground.opacity(0.3))
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.glassBorder.opacity(0.3), Color.naviCyan.opacity(0.1), Color.glassBorder.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
        )
        .padding(.horizontal, 12)
    }

    private func dockButton(_ item: FloatingPanelType) -> some View {
        let isActive = panelManager.activePanel == item
        let hasActivity = item == .agents && !agentRunner.agents.filter({ $0.status.isActive }).isEmpty

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                panelManager.show(item)
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        // Glow behind icon when active
                        if isActive {
                            Circle()
                                .fill(item.accentColor.opacity(0.2))
                                .frame(width: 30, height: 22)
                                .blur(radius: 6)
                        }

                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: isActive ? .bold : .medium))
                            .foregroundColor(isActive ? item.accentColor : .secondary.opacity(0.8))
                            .shadow(color: isActive ? item.accentColor.opacity(0.6) : .clear, radius: 4)
                    }
                    .frame(width: 34, height: 26)

                    if hasActivity {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                            .shadow(color: .green.opacity(0.6), radius: 3)
                            .offset(x: 2, y: -2)
                    }
                }

                Text(item.label)
                    .font(.system(size: 9, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? item.accentColor : .secondary.opacity(0.6))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? item.accentColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isActive ? item.accentColor.opacity(0.2) : Color.clear, lineWidth: 0.5)
                    )
            )
            .scaleEffect(isActive ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
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
