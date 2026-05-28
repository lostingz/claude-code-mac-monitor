import Foundation

struct StatusLineData: Codable {
    let sessionId: String?
    let model: ModelInfo?
    let cost: CostInfo?
    let contextWindow: ContextWindowInfo?
    let workspace: WorkspaceInfo?
    let version: String?
    let rateLimits: RateLimitsInfo?
    let effort: EffortInfo?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case model, cost
        case contextWindow = "context_window"
        case workspace, version
        case rateLimits = "rate_limits"
        case effort
    }
}

struct ModelInfo: Codable {
    let id: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct CostInfo: Codable {
    let totalCostUsd: Double?
    let totalDurationMs: Double?
    let totalLinesAdded: Int?
    let totalLinesRemoved: Int?

    enum CodingKeys: String, CodingKey {
        case totalCostUsd = "total_cost_usd"
        case totalDurationMs = "total_duration_ms"
        case totalLinesAdded = "total_lines_added"
        case totalLinesRemoved = "total_lines_removed"
    }
}

struct ContextWindowInfo: Codable {
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
    let contextWindowSize: Int?
    let usedPercentage: Double?
    let remainingPercentage: Double?
    let currentUsage: CurrentUsage?

    enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case contextWindowSize = "context_window_size"
        case usedPercentage = "used_percentage"
        case remainingPercentage = "remaining_percentage"
        case currentUsage = "current_usage"
    }
}

struct CurrentUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct WorkspaceInfo: Codable {
    let currentDir: String?
    let projectDir: String?
    let gitWorktree: String?

    enum CodingKeys: String, CodingKey {
        case currentDir = "current_dir"
        case projectDir = "project_dir"
        case gitWorktree = "git_worktree"
    }
}

struct RateLimitsInfo: Codable {
    let fiveHour: RateLimitBucket?
    let sevenDay: RateLimitBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct RateLimitBucket: Codable {
    let usedPercentage: Double?
    let resetsAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}

struct EffortInfo: Codable {
    let level: String?
}
