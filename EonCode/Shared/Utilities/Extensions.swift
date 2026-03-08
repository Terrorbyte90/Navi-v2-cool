import Foundation
import SwiftUI
import os

// MARK: - App Logger

enum NaviLog {
    private static let logger = Logger(subsystem: "com.navi.app", category: "general")

    static func error(_ message: String, error: Error? = nil) {
        if let error {
            logger.error("\(message): \(error.localizedDescription)")
        } else {
            logger.error("\(message)")
        }
    }

    static func warning(_ message: String) {
        logger.warning("\(message)")
    }

    static func info(_ message: String) {
        logger.info("\(message)")
    }
}

// MARK: - String
extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }

    func truncated(to length: Int, suffix: String = "…") -> String {
        count > length ? String(prefix(length)) + suffix : self
    }

    var lines: [String] { components(separatedBy: "\n") }

    var lineCount: Int { lines.count }

    func ranges(of substring: String, options: CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = startIndex
        while let range = range(of: substring, options: options, range: start..<endIndex) {
            ranges.append(range)
            start = range.upperBound
        }
        return ranges
    }
}

// MARK: - URL
extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    var fileSize: Int64 {
        (try? resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
    }

    var modificationDate: Date {
        (try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
    }

    func appending(components: [String]) -> URL {
        components.reduce(self) { $0.appendingPathComponent($1) }
    }
}

// MARK: - Date
extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }

    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    static func from(iso8601 string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - Data
extension Data {
    func decoded<T: Decodable>(as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: self)
    }
}

extension Encodable {
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func encodedString() throws -> String {
        String(data: try encoded(), encoding: .utf8) ?? ""
    }
}

// MARK: - Keyboard Helpers

/// Dismiss the software keyboard. No-op on macOS.
func dismissKeyboard() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
    #endif
}

// MARK: - View Modifiers
extension View {

    func glassBackground(radius: CGFloat = 16, opacity: Double = 0.15) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    func cardStyle() -> some View {
        self
            .padding()
            .glassBackground()
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Color (system-adaptive, follows system light/dark mode)
extension Color {
    static var codeBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.10, alpha: 1) : UIColor(white: 0.95, alpha: 1) })
        #endif
    }
    static var chatBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }
    static var sidebarBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor.secondarySystemBackground)
        #endif
    }
    static var accentNavi: Color { Color(red: 0.3, green: 0.6, blue: 1.0) }
    static var assistantBubble: Color { Color.clear }
    static var userBubble: Color {
        #if os(macOS)
        Color(NSColor.controlColor)
        #else
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.185, alpha: 1) : UIColor(white: 0.92, alpha: 1) })
        #endif
    }
    static var inputBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.185, alpha: 1) : UIColor(white: 0.93, alpha: 1) })
        #endif
    }
    static var inputBorder: Color {
        #if os(macOS)
        Color(NSColor.separatorColor)
        #else
        Color(UIColor.separator)
        #endif
    }
    static var surfaceHover: Color {
        #if os(macOS)
        Color(NSColor.selectedContentBackgroundColor).opacity(0.08)
        #else
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1) : UIColor(white: 0.88, alpha: 1) })
        #endif
    }
    static var dividerColor: Color {
        #if os(macOS)
        Color(NSColor.separatorColor)
        #else
        Color(UIColor.separator)
        #endif
    }

    // MARK: - Vivid accent palette for master chat
    static var naviCyan: Color { Color(red: 0.0, green: 0.87, blue: 0.87) }
    static var naviMagenta: Color { Color(red: 0.85, green: 0.2, blue: 0.65) }
    static var naviViolet: Color { Color(red: 0.55, green: 0.3, blue: 1.0) }
    static var naviMint: Color { Color(red: 0.2, green: 0.9, blue: 0.7) }
    static var naviAmber: Color { Color(red: 1.0, green: 0.75, blue: 0.2) }

    /// Gradient used for the Navi "orb" / avatar
    static var naviGradientColors: [Color] {
        [naviCyan, naviViolet, naviMagenta]
    }

    /// Deep dark background for chat-centric layout
    static var masterBackground: Color {
        #if os(macOS)
        Color(red: 0.06, green: 0.06, blue: 0.09)
        #else
        Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1)
            : UIColor.systemBackground })
        #endif
    }

    /// Glass panel surface
    static var glassSurface: Color {
        #if os(macOS)
        Color.white.opacity(0.06)
        #else
        Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.06)
            : UIColor(white: 0.0, alpha: 0.04) })
        #endif
    }

    /// Floating panel border
    static var glassBorder: Color {
        Color.white.opacity(0.12)
    }
}

// MARK: - Animated Mesh Background

struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate * 0.3
                let w = size.width
                let h = size.height

                // Draw soft gradient orbs that drift
                let orbs: [(Color, CGFloat, CGFloat, CGFloat)] = [
                    (.naviViolet.opacity(0.12), 0.3, 0.4, 180),
                    (.naviCyan.opacity(0.08), 0.7, 0.3, 220),
                    (.naviMagenta.opacity(0.06), 0.5, 0.7, 260),
                    (.naviMint.opacity(0.05), 0.2, 0.8, 140),
                ]

                for (color, baseX, baseY, radius) in orbs {
                    let x = w * baseX + sin(t * 0.7 + Double(baseX * 10)) * w * 0.08
                    let y = h * baseY + cos(t * 0.5 + Double(baseY * 10)) * h * 0.06
                    let r = radius + sin(t * 0.3) * 20

                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    let gradient = Gradient(colors: [color, color.opacity(0)])
                    let shading = GraphicsContext.Shading.radialGradient(
                        gradient,
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: r
                    )
                    context.fill(Path(ellipseIn: rect), with: shading)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Navi Orb (animated avatar)

struct NaviOrb: View {
    var size: CGFloat = 40
    var isActive: Bool = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Outer glow
            if isActive {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.naviCyan.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.9
                        )
                    )
                    .frame(width: size * 1.6, height: size * 1.6)
            }

            // Gradient orb
            Circle()
                .fill(
                    AngularGradient(
                        colors: Color.naviGradientColors + [Color.naviGradientColors[0]],
                        center: .center,
                        startAngle: .degrees(rotation),
                        endAngle: .degrees(rotation + 360)
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: 1)

            // Inner highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size, height: size)

            // Sparkle icon
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
        .onAppear {
            if isActive {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }
}

// MARK: - Assistant Avatar (updated)

struct AssistantAvatar: View {
    var size: CGFloat = 28

    var body: some View {
        NaviOrb(size: size, isActive: false)
    }
}

// MARK: - Int64
extension Int64 {
    var formattedFileSize: String {
        let bytes = Double(self)
        if bytes < 1024 { return "\(self) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", bytes / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", bytes / (1024 * 1024)) }
        return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
    }
}

// MARK: - Task
extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Int
extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
