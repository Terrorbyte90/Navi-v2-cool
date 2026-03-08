import SwiftUI

// MARK: - MasterChatView: The central über-agent chat
// This is THE interface. Everything else is a floating panel launched from here.

struct MasterChatView: View {
    @StateObject private var manager = ChatManager.shared
    @StateObject private var panelManager = FloatingPanelManager.shared
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var orchestrator = NaviOrchestrator.shared

    @State private var inputText = ""
    @State private var selectedImages: [Data] = []
    @State private var isShowingImagePicker = false
    @State private var showVoiceMode = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showDock = false
    @FocusState private var inputFocused: Bool

    var conversation: ChatConversation? { manager.activeConversation }

    var body: some View {
        ZStack {
            // Layer 1: Animated background
            Color.masterBackground.ignoresSafeArea()
            AnimatedMeshBackground()

            // Layer 2: Chat content
            VStack(spacing: 0) {
                // Top bar
                masterTopBar

                // Chat area
                if let conv = conversation {
                    chatContent(conv)
                } else {
                    masterEmptyState
                }
            }

            // Layer 3: Floating panels
            floatingPanelOverlay

            // Layer 4: Dim overlay with blur when panel is shown
            if panelManager.activePanel != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial.opacity(0.3))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            panelManager.dismiss()
                        }
                    }
                    .transition(.opacity.animation(.easeOut(duration: 0.25)))
                    .zIndex(50)
            }

            // Layer 5: The actual floating panel
            floatingPanels
                .zIndex(60)
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImages: $selectedImages)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceModeOverlay(isPresented: $showVoiceMode)
        }
        #else
        .sheet(isPresented: $showVoiceMode) {
            VoiceModeOverlay(isPresented: $showVoiceMode)
                .frame(minWidth: 500, minHeight: 400)
        }
        #endif
        .onAppear {
            if manager.activeConversation == nil && !manager.conversations.isEmpty {
                manager.activeConversation = manager.conversations.first
            }
        }
    }

    // MARK: - Top Bar

    private var masterTopBar: some View {
        HStack(spacing: 12) {
            // Navi orb + title
            HStack(spacing: 8) {
                NaviOrb(size: 24, isActive: manager.isStreaming || orchestrator.activity.isActive)

                if let conv = conversation {
                    Menu {
                        Section("Anthropic") {
                            ForEach(ClaudeModel.anthropicModels) { model in
                                Button {
                                    updateModel(model, for: conv)
                                } label: {
                                    HStack {
                                        Text(model.displayName)
                                        if model == conv.model { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                        Section("xAI / Grok") {
                            ForEach(ClaudeModel.xaiModels) { model in
                                Button {
                                    updateModel(model, for: conv)
                                } label: {
                                    HStack {
                                        Text(model.displayName)
                                        if model == conv.model { Image(systemName: "checkmark") }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Navi")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(conv.model.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.naviCyan.opacity(0.8))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.naviCyan.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    #endif
                } else {
                    Text("Navi")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Active project indicator
            if let project = projectStore.activeProject {
                HStack(spacing: 5) {
                    Circle()
                        .fill(project.color.color)
                        .frame(width: 6, height: 6)
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
            }

            // Session cost
            SessionCostLabel(fontSize: 11, opacity: 0.5)

            // New chat button
            Button { _ = manager.newConversation() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack(alignment: .bottom) {
                Color.masterBackground.opacity(0.75)
                    .background(.ultraThinMaterial.opacity(0.5))

                // Subtle gradient edge
                LinearGradient(
                    colors: [Color.naviCyan.opacity(0.06), Color.naviViolet.opacity(0.04), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
            }
        )
    }

    // MARK: - Chat Content

    private func chatContent(_ conv: ChatConversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(conv.messages) { msg in
                        MasterChatBubble(message: msg)
                            .id(msg.id)
                    }

                    if manager.isStreaming {
                        StreamingBubble(text: manager.streamingText)
                            .id("streaming")
                    }

                    Color.clear.frame(height: 1).id("bottomAnchor")
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    // Agent activity overlay
                    AgentActivityOverlay()

                    // Quick action dock
                    if showDock {
                        QuickActionDock()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 4)
                    }

                    // Input bar
                    masterInputBar
                }
                .background(
                    Color.masterBackground.opacity(0.85)
                        .background(.ultraThinMaterial)
                )
            }
            .onAppear { scrollProxy = proxy; scrollToBottom(proxy, animated: false) }
            .onChange(of: conv.messages.count) { scrollToBottom(proxy, animated: true) }
            .onChange(of: manager.streamingText.count / 80) { _ in
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    // MARK: - Empty State

    private var masterEmptyState: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Large animated orb with enhanced glow
                    ZStack {
                        // Soft background glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.naviCyan.opacity(0.08), .naviViolet.opacity(0.04), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)

                        NaviOrb(size: 80, isActive: true)
                    }
                    .padding(.bottom, 4)

                    VStack(spacing: 10) {
                        Text("Navi")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .naviCyan.opacity(0.9), .naviViolet.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .naviCyan.opacity(0.3), radius: 10)

                        Text("Din master-agent. Fråga mig vad som helst.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.5))
                    }

                    // Quick suggestion chips with staggered appearance
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        suggestionChip("Skapa ett nytt projekt", icon: "folder.badge.plus", color: .naviCyan)
                        suggestionChip("Planera en app-idé", icon: "lightbulb.fill", color: .naviAmber)
                        suggestionChip("Hjälp mig med kod", icon: "chevron.left.forwardslash.chevron.right", color: .naviViolet)
                        suggestionChip("Generera en bild", icon: "photo.fill", color: .naviMagenta)
                        suggestionChip("Öppna inställningar", icon: "gearshape.fill", color: .secondary)
                        suggestionChip("Visa media", icon: "photo.stack.fill", color: .pink)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 120)
                }
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }
            }

            VStack(spacing: 0) {
                if showDock {
                    QuickActionDock()
                        .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                        .padding(.bottom, 4)
                }
                masterInputBar
            }
            .background(
                Color.masterBackground.opacity(0.85)
                    .background(.ultraThinMaterial)
            )
        }
    }

    private func suggestionChip(_ text: String, icon: String, color: Color) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.4), radius: 3)
                }
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [color.opacity(0.25), Color.glassBorder.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.6
                            )
                    )
                    .shadow(color: color.opacity(0.06), radius: 8, y: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Master Input Bar

    private var masterInputBar: some View {
        VStack(spacing: 6) {
            // Image previews
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, data in
                            ZStack(alignment: .topTrailing) {
                                #if os(iOS)
                                if let ui = UIImage(data: data) {
                                    Image(uiImage: ui).resizable().scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                #else
                                if let ns = NSImage(data: data) {
                                    Image(nsImage: ns).resizable().scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                #endif
                                Button { selectedImages.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                }
            }

            // Main input pill
            HStack(alignment: .center, spacing: 8) {
                // Dock toggle
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showDock.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(showDock ? Color.naviCyan.opacity(0.15) : Color.glassSurface)
                            .frame(width: 30, height: 30)
                        Image(systemName: showDock ? "xmark" : "square.grid.2x2")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(showDock ? .naviCyan : .secondary)
                    }
                }
                .buttonStyle(.plain)

                // Attach button
                Menu {
                    Button { isShowingImagePicker = true } label: {
                        Label("Bild", systemImage: "photo")
                    }
                    #if os(iOS)
                    Button { isShowingImagePicker = true } label: {
                        Label("Kamera", systemImage: "camera")
                    }
                    #endif
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.glassSurface)
                            .frame(width: 30, height: 30)
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                #if os(macOS)
                .menuStyle(.borderlessButton)
                #endif

                TextField("Be Navi om vad som helst…", text: $inputText, axis: .vertical)
                    .focused($inputFocused)
                    .font(.callout)
                    .foregroundColor(.white)
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 10)
                    .padding(.leading, 4)

                // Send / Stop / Voice
                if manager.isStreaming {
                    Button(action: sendMessage) {
                        ZStack {
                            Circle()
                                .fill(Color.naviCyan)
                                .frame(width: 30, height: 30)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.masterBackground)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .buttonStyle(.plain)
                } else if inputText.isBlank && selectedImages.isEmpty {
                    Button { showVoiceMode = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 30, height: 30)
                            Image(systemName: "waveform")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendMessage) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.naviCyan, .naviViolet],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 30, height: 30)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.glassSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.naviCyan.opacity(0.2), Color.glassBorder.opacity(0.3), Color.naviViolet.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 0.6
                            )
                    )
            )

            // Bottom disclaimer
            HStack {
                Text("Navi kan göra misstag. Kontrollera viktig information.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.3))
                Spacer()
                SessionCostLabel(fontSize: 10, opacity: 0.25)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Panel Toast (visual feedback when opening panels from chat)

    @ViewBuilder
    private func panelToast(_ panel: FloatingPanelType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: panel.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(panel.accentColor)
            Text("Öppnar \(panel.label)…")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(panel.accentColor.opacity(0.3), lineWidth: 0.6)
                )
                .shadow(color: panel.accentColor.opacity(0.15), radius: 12, y: 4)
        )
    }

    // MARK: - Floating Panel Overlay

    private var floatingPanelOverlay: some View {
        EmptyView() // Panels handled in floatingPanels
    }

    @ViewBuilder
    private var floatingPanels: some View {
        if let panel = panelManager.activePanel {
            FloatingPanelContainer(
                panelType: panel,
                isPresented: true,
                onDismiss: { panelManager.dismiss() }
            ) {
                floatingPanelContent(panel)
            }
        }
    }

    @ViewBuilder
    private func floatingPanelContent(_ panel: FloatingPanelType) -> some View {
        switch panel {
        case .browser:
            BrowserView()
        case .artifacts:
            ArtifactView()
        case .plan:
            PlanView()
        case .github:
            GitHubView()
        case .agents:
            AgentView()
        case .media:
            MediaView()
        case .settings:
            SettingsView()
        case .project:
            if let project = projectStore.activeProject {
                let agent = AgentPool.shared.agent(for: project)
                ChatView(agent: agent)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Inget aktivt projekt")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .code:
            if let project = projectStore.activeProject {
                FileTreeAndEditorPanel(project: project)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Välj ett projekt för att visa kod")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .todo:
            todoFloatingPanel
        }
    }

    private var todoFloatingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            let activity = orchestrator.activity
            if !activity.todoItems.isEmpty {
                AgentActivityView(activity: activity, compact: false)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checklist")
                        .font(.system(size: 40))
                        .foregroundColor(.naviMint.opacity(0.3))
                    Text("Inga aktiva uppgifter")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text("Be Navi göra något så visas framstegen här.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !inputText.isBlank || !selectedImages.isEmpty else { return }

        // Check for panel-opening intents before sending to AI
        let lower = inputText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let panel = detectPanelIntent(lower) {
            panelManager.show(panel)
            inputText = ""
            return
        }

        // Check for image generation intent
        if detectImageGenerationIntent(lower) {
            let imagePrompt = extractImagePrompt(from: inputText)
            panelManager.show(.media)
            if !imagePrompt.isEmpty {
                // Trigger generation via MediaGenerationManager
                Task {
                    await MediaGenerationManager.shared.generateImage(prompt: imagePrompt)
                }
            }
            inputText = ""
            return
        }

        if manager.activeConversation == nil {
            _ = manager.newConversation()
        }
        guard let convID = manager.activeConversation?.id else { return }

        let text = inputText
        let images = selectedImages
        inputText = ""
        selectedImages = []

        Task {
            guard var conv = manager.conversations.first(where: { $0.id == convID })
                    ?? manager.activeConversation
            else { return }

            try? await manager.send(text: text, images: images, in: &conv) { _ in }
            await MainActor.run {
                manager.activeConversation = conv
                if let idx = manager.conversations.firstIndex(where: { $0.id == conv.id }) {
                    manager.conversations[idx] = conv
                }
            }
        }
    }

    // MARK: - Intent Detection

    /// Detects if the user wants to open a specific panel
    private func detectPanelIntent(_ text: String) -> FloatingPanelType? {
        let panelKeywords: [(FloatingPanelType, [String])] = [
            (.settings, ["öppna inställningar", "visa inställningar", "settings", "inställningar", "api-nycklar", "api nycklar"]),
            (.media, ["öppna media", "visa media", "media panel"]),
            (.browser, ["öppna webbläsare", "visa webb", "öppna webb", "browse"]),
            (.github, ["öppna github", "visa github"]),
            (.plan, ["öppna plan", "visa plan", "planer"]),
            (.agents, ["öppna agenter", "visa agenter", "mina agenter"]),
            (.artifacts, ["öppna artefakter", "visa artefakter"]),
            (.code, ["öppna kod", "visa kod", "kodredigera", "visa filer"]),
            (.project, ["öppna projekt", "visa projekt", "projektvy"]),
            (.todo, ["öppna att göra", "visa uppgifter", "todo", "att göra"]),
        ]

        for (panel, keywords) in panelKeywords {
            for keyword in keywords {
                if text == keyword || text.hasPrefix(keyword) {
                    return panel
                }
            }
        }
        return nil
    }

    /// Detects if the user wants to generate an image
    private func detectImageGenerationIntent(_ text: String) -> Bool {
        let imageKeywords = ["generera en bild", "skapa en bild", "generera bild", "skapa bild",
                             "generate image", "generate an image", "create image", "rita en bild"]
        return imageKeywords.contains(where: { text.hasPrefix($0) })
    }

    /// Extracts the image prompt from user text (after the intent keyword)
    private func extractImagePrompt(from text: String) -> String {
        let prefixes = ["generera en bild av ", "generera en bild: ", "generera en bild på ",
                        "skapa en bild av ", "skapa en bild: ", "skapa en bild på ",
                        "generera bild av ", "generera bild: ", "generera bild på ",
                        "skapa bild av ", "skapa bild: ", "skapa bild på ",
                        "generate image of ", "generate image: ", "generate an image of ",
                        "create image of ", "create image: ", "rita en bild av ", "rita en bild på "]
        let lower = text.lowercased()
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        // Fallback: remove the command part
        let commandPrefixes = ["generera en bild", "skapa en bild", "generera bild", "skapa bild",
                               "generate image", "generate an image", "create image", "rita en bild"]
        for prefix in commandPrefixes {
            if lower.hasPrefix(prefix) {
                let rest = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return rest
            }
        }
        return ""
    }

    private func updateModel(_ model: ClaudeModel, for conv: ChatConversation) {
        if let idx = manager.conversations.firstIndex(where: { $0.id == conv.id }) {
            manager.conversations[idx].model = model
            manager.activeConversation?.model = model
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = false) {
        let action = { proxy.scrollTo("bottomAnchor", anchor: .bottom) }
        if animated { withAnimation(.easeOut(duration: 0.15)) { action() } }
        else { action() }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Master Chat Bubble (vivid styling)

struct MasterChatBubble: View {
    let message: PureChatMessage
    @State private var isSpeaking = false
    @State private var appeared = false

    var isUser: Bool { message.role == .user }

    var body: some View {
        Group {
            if isUser {
                userBubble
            } else {
                assistantBubble
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
    }

    // User: right-aligned with vivid gradient pill
    private var userBubble: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 6) {
                if let imgs = message.imageData, !imgs.isEmpty {
                    imageRow(imgs)
                }
                Text(message.content)
                    .font(.system(size: 15.5))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.naviViolet.opacity(0.3),
                                        Color.naviCyan.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.naviViolet.opacity(0.3), Color.naviCyan.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.6
                                    )
                            )
                            .shadow(color: Color.naviViolet.opacity(0.08), radius: 8, y: 2)
                    )
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // Assistant: left-aligned with orb avatar + glass background
    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            NaviOrb(size: 26, isActive: false)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                MarkdownTextView(text: ResponseCleaner.clean(message.content))
                    .equatable()
                    .textSelection(.enabled)

                // Action row with hover-ready buttons
                HStack(spacing: 12) {
                    bubbleAction(icon: "doc.on.doc") {
                        #if os(iOS)
                        UIPasteboard.general.string = message.content
                        #else
                        NSPasteboard.general.setString(message.content, forType: .string)
                        #endif
                    }

                    bubbleAction(icon: isSpeaking ? "stop.circle.fill" : "speaker.wave.2") {
                        if isSpeaking {
                            ElevenLabsClient.shared.stop()
                            isSpeaking = false
                        } else {
                            isSpeaking = true
                            Task {
                                await ElevenLabsClient.shared.speak(message.content)
                                isSpeaking = false
                            }
                        }
                    }

                    if let cost = message.costSEK, cost > 0 {
                        CostBadge(costSEK: cost, usage: message.tokenUsage, model: message.model)
                    }
                }
                .foregroundColor(.secondary.opacity(0.45))
                .padding(.top, 2)
            }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func bubbleAction(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func imageRow(_ imgs: [Data]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(imgs.enumerated()), id: \.offset) { _, data in
                    #if os(iOS)
                    if let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    }
                    #else
                    if let ns = NSImage(data: data) {
                        Image(nsImage: ns).resizable().scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    }
                    #endif
                }
            }
        }
    }
}

// MARK: - File Tree & Editor Panel (for floating code panel)

struct FileTreeAndEditorPanel: View {
    let project: NaviProject
    @State private var selectedNode: FileNode?
    @State private var fileContent = ""

    var body: some View {
        #if os(macOS)
        HSplitView {
            FileTreeView(project: project, selectedNode: $selectedNode)
                .frame(minWidth: 160, maxWidth: 240)
            editorOrPlaceholder
        }
        #else
        HStack(spacing: 0) {
            FileTreeView(project: project, selectedNode: $selectedNode)
                .frame(maxWidth: 200)
            Divider().opacity(0.1)
            editorOrPlaceholder
        }
        #endif
    }

    @ViewBuilder
    var editorOrPlaceholder: some View {
        if let node = selectedNode, !node.isDirectory {
            CodeEditorView(
                content: $fileContent,
                fileType: node.fileType,
                onSave: { newContent in
                    try? newContent.write(toFile: node.path, atomically: true, encoding: .utf8)
                }
            )
            .onAppear { fileContent = (try? String(contentsOfFile: node.path)) ?? "" }
            .onChange(of: selectedNode?.id) {
                if let n = selectedNode, !n.isDirectory {
                    fileContent = (try? String(contentsOfFile: n.path)) ?? ""
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary.opacity(0.2))
                Text("Välj en fil")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Preview

#Preview("MasterChatView") {
    MasterChatView()
        .frame(width: 500, height: 800)
}
