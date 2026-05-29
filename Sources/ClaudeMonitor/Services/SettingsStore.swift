import Foundation

/// Safe read/write helper for ~/.claude/settings.json.
///
/// Both SetupService (install/uninstall) and ApprovalPanel (always-allow) mutate
/// the user's central Claude Code config. This funnels every write through one
/// path that: makes a one-time backup per launch, writes atomically, and
/// propagates errors instead of silently swallowing them with `try?`.
enum SettingsStore {
    enum SettingsError: LocalizedError {
        /// The file exists but is not a JSON object — never clobber it.
        case invalidJSON
        case serializationFailed
        case writeFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "settings.json 不是合法的 JSON 对象"
            case .serializationFailed:
                return "无法序列化 settings.json"
            case .writeFailed(let underlying):
                return "写入失败: \(underlying.localizedDescription)"
            }
        }
    }

    static var claudeDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.claude"
    }

    static var settingsPath: String {
        claudeDir + "/settings.json"
    }

    private static let backupLock = NSLock()
    private static var didBackupThisLaunch = false

    /// Reads settings. Returns `[:]` if the file is missing or empty (caller may
    /// create it). Throws `.invalidJSON` if the file exists but isn't a JSON object.
    static func read() throws -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: settingsPath), !data.isEmpty else {
            return [:]
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else {
            throw SettingsError.invalidJSON
        }
        return dict
    }

    /// Ensures `~/.claude` exists and `settings.json` exists (created as `{}` if absent).
    /// Does NOT touch an existing file. Throws if the directory/file can't be created.
    static func ensureExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: claudeDir) {
            try fm.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: settingsPath) {
            try Data("{}".utf8).write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
        }
    }

    /// Serializes and writes settings atomically, making one timestamped-state backup
    /// (`settings.json.bak`) before the first mutation of this app launch.
    static func write(_ settings: [String: Any]) throws {
        guard let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            throw SettingsError.serializationFailed
        }

        backupOnce()

        do {
            try data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
        } catch {
            throw SettingsError.writeFailed(underlying: error)
        }
    }

    /// Copies settings.json -> settings.json.bak once per launch (best-effort).
    private static func backupOnce() {
        backupLock.lock()
        defer { backupLock.unlock() }
        guard !didBackupThisLaunch else { return }
        didBackupThisLaunch = true

        let fm = FileManager.default
        guard fm.fileExists(atPath: settingsPath) else { return }
        let backupPath = settingsPath + ".bak"
        try? fm.removeItem(atPath: backupPath)
        try? fm.copyItem(atPath: settingsPath, toPath: backupPath)
    }
}
