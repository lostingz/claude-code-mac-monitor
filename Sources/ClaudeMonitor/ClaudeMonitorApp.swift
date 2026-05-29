import AppKit
import SwiftUI

@main
struct ClaudeMonitorApp {
    static let appState = AppState()
    static var hookServer: HookServer!
    static var statusWatcher: StatusFileWatcher!
    static var statusItem: NSStatusItem!
    static var popover: NSPopover!
    static var approvalWindowController: ApprovalWindowController?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    static func showApproval(_ request: ApprovalRequest) {
        debugLog("[App] Approval requested: \(request.toolName)")
        DispatchQueue.main.async {
            let controller = ApprovalWindowController(request: request)
            approvalWindowController = controller
            controller.showWindow(nil)
            NSSound.beep()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = ClaudeMonitorApp.appState
        state.setupResult = SetupService.installIfNeeded()

        ClaudeMonitorApp.hookServer = HookServer(appState: state)
        ClaudeMonitorApp.hookServer.start()

        ClaudeMonitorApp.statusWatcher = StatusFileWatcher(appState: state)
        ClaudeMonitorApp.statusWatcher.start()

        setupStatusItem(state: state)
        startStateObservation(state: state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClaudeMonitorApp.hookServer?.stop()
        ClaudeMonitorApp.statusWatcher?.stop()
    }

    private func setupStatusItem(state: AppState) {
        ClaudeMonitorApp.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusIcon(state: state)

        ClaudeMonitorApp.popover = NSPopover()
        ClaudeMonitorApp.popover.contentSize = NSSize(width: 340, height: 520)
        ClaudeMonitorApp.popover.behavior = .transient
        ClaudeMonitorApp.popover.appearance = NSAppearance(named: .darkAqua)
        ClaudeMonitorApp.popover.contentViewController = NSHostingController(
            rootView: MenuBarPopover(appState: state)
        )

        if let button = ClaudeMonitorApp.statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            if ClaudeMonitorApp.popover.isShown {
                ClaudeMonitorApp.popover.performClose(nil)
            }
        }
    }

    private func startStateObservation(state: AppState) {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatusIcon(state: state)
        }
    }

    private func updateStatusIcon(state: AppState) {
        guard let button = ClaudeMonitorApp.statusItem?.button else { return }

        let symbolName: String
        let color: NSColor

        switch state.status {
        case .inactive:
            symbolName = "circle"
            color = .systemGray
        case .idle:
            symbolName = "circle.fill"
            color = .systemGray
        case .working:
            symbolName = "circle.fill"
            color = .systemGreen
        case .callingTool:
            symbolName = "gearshape.fill"
            color = .systemBlue
        case .waitingApproval:
            symbolName = "exclamationmark.circle.fill"
            color = .systemOrange
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Claude Status") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            let coloredImage = configured.tinted(with: color)
            button.image = coloredImage
        }

        if let setup = state.setupResult, setup.outcome == .failed, let first = setup.messages.first {
            button.toolTip = "ClaudeMonitor 安装失败: \(first)"
        } else {
            button.toolTip = "Claude Code: \(state.status.label)"
        }
    }

    @objc private func togglePopover() {
        guard let button = ClaudeMonitorApp.statusItem.button else { return }
        if ClaudeMonitorApp.popover.isShown {
            ClaudeMonitorApp.popover.performClose(nil)
        } else {
            ClaudeMonitorApp.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
