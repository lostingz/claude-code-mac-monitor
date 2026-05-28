import AppKit
import SwiftUI

class ApprovalWindowController: NSWindowController, NSWindowDelegate {
    let request: ApprovalRequest

    init(request: ApprovalRequest) {
        self.request = request
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Code - Permission Request"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1.0)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.appearance = NSAppearance(named: .darkAqua)

        super.init(window: window)
        window.delegate = self

        let view = ApprovalPanelView(request: request)
        window.contentViewController = NSHostingController(rootView: view)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        super.showWindow(sender)
    }

    func windowWillClose(_ notification: Notification) {
        request.completion(false)
        ClaudeMonitorApp.approvalWindowController = nil
    }
}

struct ApprovalPanelView: View {
    let request: ApprovalRequest
    @State private var alwaysAllow = false
    @State private var borderPulse: Double = 0.4
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            dividerLine(.techOrange)
            contentArea
            Spacer(minLength: 0)
            dividerLine(.techOrange)
            actionBar
        }
        .frame(width: 480, height: 360)
        .background(Color.techBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.techOrange.opacity(borderPulse), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1.0 : 0.95)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                borderPulse = 0.8
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.techOrange)
                .shadow(color: .techOrange.opacity(0.5), radius: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text("PERMISSION REQUEST")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .kerning(1.5)
                Text("Claude Code requires authorization")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Spacer()
        }
        .padding(16)
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("TOOL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.techCyan.opacity(0.5))
                    .kerning(1)
                Image(systemName: toolIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.techCyan)
                Text(request.toolName)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
            }

            if let detail = detailText, !detail.isEmpty {
                ScrollView {
                    HStack(alignment: .top, spacing: 8) {
                        Text("$")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.techGreen.opacity(0.5))
                        Text(detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.techGreen.opacity(0.85))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(maxHeight: 120)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.techGreen.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $alwaysAllow) {
                Text("Always allow \(request.toolName)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .toggleStyle(.checkbox)

            Spacer()

            Button(action: { decide(allow: false) }) {
                Text("DENY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(Color.techRed)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.techRed.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.techRed.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Button(action: { decide(allow: true) }) {
                Text("ALLOW")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.techGreen.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.techGreen.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: .techGreen.opacity(0.2), radius: 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(16)
    }

    private func dividerLine(_ color: Color) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0), color.opacity(0.3), color.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
    }

    private func decide(allow: Bool) {
        if allow && alwaysAllow {
            addToAllowList(toolName: request.toolName, detail: request.toolInput?.displaySummary)
        }
        request.completion(allow)
        NSApp.keyWindow?.close()
    }

    private var toolIcon: String {
        switch request.toolName {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Edit": return "pencil"
        case "Write": return "square.and.pencil"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass"
        case "Agent": return "person.2"
        default:
            if request.toolName.hasPrefix("mcp_") { return "puzzlepiece" }
            return "wrench"
        }
    }

    private var detailText: String? {
        guard let input = request.toolInput else { return nil }
        if let cmd = input.command { return cmd }
        if let fp = input.filePath {
            var text = fp
            if let old = input.oldString, let new = input.newString {
                text += "\n- \(String(old.prefix(200)))\n+ \(String(new.prefix(200)))"
            }
            return text
        }
        if let url = input.url { return url }
        if let query = input.query { return query }
        return input.displaySummary
    }

    private func addToAllowList(toolName: String, detail: String?) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let settingsPath = "\(home)/.claude/settings.json"
        guard let data = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var permissions = settings["permissions"] as? [String: Any],
              var allowList = permissions["allow"] as? [String] else { return }

        let permission = detail.map { "\(toolName)(\(String($0.prefix(50))):*)" } ?? toolName
        if !allowList.contains(permission) {
            allowList.append(permission)
            permissions["allow"] = allowList
            settings["permissions"] = permissions
            if let newData = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
                try? newData.write(to: URL(fileURLWithPath: settingsPath))
            }
        }
    }
}
