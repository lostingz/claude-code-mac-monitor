import Foundation

/// Result of the first-launch auto-install, surfaced to the user via AppState/MenuBarPopover.
struct SetupResult: Equatable {
    enum Outcome { case ok, warning, failed }
    let outcome: Outcome
    let messages: [String]
}

struct SetupService {
    static let hookPort: UInt16 = 19806
    private static let hookURL = "http://127.0.0.1:\(hookPort)/hook"

    /// Installs the statusline wrapper and HTTP hooks into ~/.claude/settings.json.
    /// Never silently no-ops: creates settings.json if missing, refuses to clobber an
    /// invalid file, and returns a result the UI can show.
    static func installIfNeeded() -> SetupResult {
        let claudeDir = SettingsStore.claudeDir

        do {
            try SettingsStore.ensureExists()
        } catch {
            return SetupResult(outcome: .failed,
                               messages: ["无法创建 ~/.claude/settings.json: \(error.localizedDescription)"])
        }

        var settings: [String: Any]
        do {
            settings = try SettingsStore.read()
        } catch {
            return SetupResult(outcome: .failed,
                               messages: ["~/.claude/settings.json 不是合法 JSON，ClaudeMonitor 未做任何修改。请修复或删除该文件后重启。"])
        }

        var warnings: [String] = []
        warnings += installStatuslineWrapper(claudeDir: claudeDir, settings: &settings)
        installHooks(settings: &settings)

        do {
            try SettingsStore.write(settings)
        } catch {
            return SetupResult(outcome: .failed,
                               messages: ["写入 settings.json 失败: \(error.localizedDescription)"])
        }

        return SetupResult(outcome: warnings.isEmpty ? .ok : .warning, messages: warnings)
    }

    static func uninstall() {
        let claudeDir = SettingsStore.claudeDir
        guard var settings = try? SettingsStore.read() else { return }
        restoreOriginalStatusline(claudeDir: claudeDir, settings: &settings)
        removeHooks(settings: &settings)
        try? SettingsStore.write(settings)
    }

    /// Wraps the existing statusline command so its JSON is tee'd to monitor-status.json.
    /// Always installs the wrapper — even for users who never configured a statusline —
    /// so the metrics channel works for everyone. Returns informational warnings.
    private static func installStatuslineWrapper(claudeDir: String, settings: inout [String: Any]) -> [String] {
        var warnings: [String] = []
        let wrapperPath = "\(claudeDir)/statusline-monitor.sh"
        let originalPath = "\(claudeDir)/statusline-command-original.sh"

        let existingCommand = (settings["statusLine"] as? [String: Any])?["command"] as? String
        let alreadyWrapped = existingCommand?.contains("statusline-monitor") == true

        if !alreadyWrapped {
            if let existingCommand, !existingCommand.isEmpty {
                // Preserve the prior statusline script's content so the wrapper can re-run it.
                let originalScriptPath = "\(claudeDir)/statusline-command.sh"
                let originalContent: String
                if let data = FileManager.default.contents(atPath: originalScriptPath) {
                    originalContent = String(data: data, encoding: .utf8) ?? "#!/bin/bash\ncat"
                } else {
                    originalContent = "#!/bin/bash\ncat"
                }
                try? originalContent.write(toFile: originalPath, atomically: true, encoding: .utf8)
            } else {
                // Fresh user: no prior statusline. Don't write an -original.sh; the wrapper
                // skips re-running when it's absent, just tee'ing input to monitor-status.json.
                warnings.append("已安装监控 statusline（此前未配置 statusline）")
            }
        }

        let wrapperContent = """
        #!/bin/bash
        input=$(cat)
        echo "$input" > "$HOME/.claude/monitor-status.json"
        ORIGINAL="$HOME/.claude/statusline-command-original.sh"
        if [ -f "$ORIGINAL" ]; then
            echo "$input" | bash "$ORIGINAL"
        fi
        """
        try? wrapperContent.write(toFile: wrapperPath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", wrapperPath]
        try? process.run()
        process.waitUntilExit()

        settings["statusLine"] = [
            "type": "command",
            "command": "bash \(wrapperPath)"
        ] as [String: Any]

        return warnings
    }

    private static func installHooks(settings: inout [String: Any]) {
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let asyncHookEntry: [String: Any] = [
            "type": "http",
            "url": hookURL,
            "timeout": 5,
            "async": true
        ]

        let permissionHookEntry: [String: Any] = [
            "type": "http",
            "url": hookURL,
            "timeout": 120
        ]

        let monitorTag = "ClaudeMonitor"

        let asyncEvents = ["PreToolUse", "PostToolUse", "PostToolUseFailure", "Stop", "Notification", "SessionStart", "SessionEnd"]
        let syncEvents: [String: [String: Any]] = [
            "PermissionRequest": permissionHookEntry
        ]

        for event in asyncEvents {
            hooks = addHookIfMissing(hooks: hooks, event: event, hookEntry: asyncHookEntry, tag: monitorTag)
        }
        for (event, entry) in syncEvents {
            hooks = addHookIfMissing(hooks: hooks, event: event, hookEntry: entry, tag: monitorTag)
        }

        settings["hooks"] = hooks
    }

    private static func addHookIfMissing(hooks: [String: Any], event: String, hookEntry: [String: Any], tag: String) -> [String: Any] {
        var hooks = hooks
        var matcherGroups = hooks[event] as? [[String: Any]] ?? []

        let alreadyInstalled = matcherGroups.contains { group in
            if let groupHooks = group["hooks"] as? [[String: Any]] {
                return groupHooks.contains { h in
                    (h["url"] as? String)?.contains("19806") == true
                }
            }
            return false
        }

        if !alreadyInstalled {
            var entry = hookEntry
            entry["_tag"] = tag
            let group: [String: Any] = [
                "matcher": "",
                "hooks": [entry]
            ]
            matcherGroups.append(group)
        }

        hooks[event] = matcherGroups
        return hooks
    }

    private static func removeHooks(settings: inout [String: Any]) {
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, value) in hooks {
            guard var groups = value as? [[String: Any]] else { continue }
            groups.removeAll { group in
                if let groupHooks = group["hooks"] as? [[String: Any]] {
                    return groupHooks.allSatisfy { h in
                        (h["url"] as? String)?.contains("19806") == true
                    }
                }
                return false
            }
            if groups.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = groups
            }
        }

        settings["hooks"] = hooks
    }

    private static func restoreOriginalStatusline(claudeDir: String, settings: inout [String: Any]) {
        let originalPath = "\(claudeDir)/statusline-command-original.sh"
        guard FileManager.default.fileExists(atPath: originalPath) else { return }

        let restoredScriptPath = "\(claudeDir)/statusline-command.sh"
        settings["statusLine"] = [
            "type": "command",
            "command": "bash \(restoredScriptPath)"
        ] as [String: Any]

        try? FileManager.default.removeItem(atPath: restoredScriptPath)
        try? FileManager.default.copyItem(atPath: originalPath, toPath: restoredScriptPath)
        try? FileManager.default.removeItem(atPath: originalPath)
    }
}
