import Foundation

struct SetupService {
    static let hookPort: UInt16 = 19806
    private static let hookURL = "http://127.0.0.1:\(hookPort)/hook"

    static func installIfNeeded() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let claudeDir = "\(home)/.claude"

        installStatuslineWrapper(claudeDir: claudeDir)
        installHooks(claudeDir: claudeDir)
    }

    static func uninstall() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let claudeDir = "\(home)/.claude"
        restoreOriginalStatusline(claudeDir: claudeDir)
        removeHooks(claudeDir: claudeDir)
    }

    private static func installStatuslineWrapper(claudeDir: String) {
        let settingsPath = "\(claudeDir)/settings.json"
        let wrapperPath = "\(claudeDir)/statusline-monitor.sh"
        let originalPath = "\(claudeDir)/statusline-command-original.sh"

        guard let settingsData = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
            return
        }

        if let statusLine = settings["statusLine"] as? [String: Any],
           let currentCommand = statusLine["command"] as? String,
           !currentCommand.contains("statusline-monitor") {
            let originalContent: String
            let originalScriptPath = "\(claudeDir)/statusline-command.sh"
            if let data = FileManager.default.contents(atPath: originalScriptPath) {
                originalContent = String(data: data, encoding: .utf8) ?? "#!/bin/bash\ncat"
            } else {
                originalContent = "#!/bin/bash\ncat"
            }
            try? originalContent.write(toFile: originalPath, atomically: true, encoding: .utf8)
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

        writeSettings(settings, to: settingsPath)
    }

    private static func installHooks(claudeDir: String) {
        let settingsPath = "\(claudeDir)/settings.json"
        guard let settingsData = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
            return
        }

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
        writeSettings(settings, to: settingsPath)
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

    private static func removeHooks(claudeDir: String) {
        let settingsPath = "\(claudeDir)/settings.json"
        guard let settingsData = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else {
            return
        }

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
        writeSettings(settings, to: settingsPath)
    }

    private static func restoreOriginalStatusline(claudeDir: String) {
        let settingsPath = "\(claudeDir)/settings.json"
        let originalPath = "\(claudeDir)/statusline-command-original.sh"

        guard let settingsData = FileManager.default.contents(atPath: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any] else {
            return
        }

        if FileManager.default.fileExists(atPath: originalPath) {
            settings["statusLine"] = [
                "type": "command",
                "command": "bash \(claudeDir)/statusline-command.sh"
            ] as [String: Any]

            try? FileManager.default.copyItem(atPath: originalPath, toPath: "\(claudeDir)/statusline-command.sh")
            try? FileManager.default.removeItem(atPath: originalPath)
        }

        writeSettings(settings, to: settingsPath)
    }

    private static func writeSettings(_ settings: [String: Any], to path: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
