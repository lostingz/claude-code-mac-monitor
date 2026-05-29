import Foundation

struct HookEvent: Codable {
    let hookEventName: String?
    let sessionId: String?
    let toolName: String?
    let toolInput: ToolInput?
    let transcriptPath: String?
    let cwd: String?
    let permissionMode: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case sessionId = "session_id"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case transcriptPath = "transcript_path"
        case cwd
        case permissionMode = "permission_mode"
        case message
    }
}

struct ToolInput: Codable {
    let command: String?
    let filePath: String?
    let content: String?
    let oldString: String?
    let newString: String?
    let url: String?
    let query: String?
    let prompt: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case command
        case filePath = "file_path"
        case content
        case oldString = "old_string"
        case newString = "new_string"
        case url, query, prompt, description
    }

    var displaySummary: String {
        if let cmd = command { return cmd }
        if let fp = filePath { return fp }
        if let u = url { return u }
        if let q = query { return q }
        if let d = description { return d }
        if let p = prompt { return String(p.prefix(100)) }
        return ""
    }
}

struct PermissionResponse: Codable {
    let hookSpecificOutput: PermissionHookOutput?
}

struct PermissionHookOutput: Codable {
    let hookEventName: String
    let decision: PermissionDecision
}

struct PermissionDecision: Codable {
    let behavior: String
}

final class ApprovalRequest: Identifiable {
    let id: UUID
    let toolName: String
    let toolInput: ToolInput?
    let sessionId: String
    let timestamp: Date
    private let _completion: (Bool) -> Void
    private var hasResponded = false

    init(id: UUID = UUID(), toolName: String, toolInput: ToolInput?, sessionId: String, timestamp: Date, completion: @escaping (Bool) -> Void) {
        self.id = id
        self.toolName = toolName
        self.toolInput = toolInput
        self.sessionId = sessionId
        self.timestamp = timestamp
        self._completion = completion
    }

    func completion(_ allowed: Bool) {
        guard !hasResponded else { return }
        hasResponded = true
        _completion(allowed)
    }
}

struct ToolHistoryEntry: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let timestamp: Date
}
