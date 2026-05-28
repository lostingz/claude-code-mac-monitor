import Foundation
import SwiftUI

enum SessionStatus: Equatable {
    case inactive
    case idle
    case working
    case callingTool(String)
    case waitingApproval

    var label: String {
        switch self {
        case .inactive: return "未连接"
        case .idle: return "空闲"
        case .working: return "工作中"
        case .callingTool(let name): return "调用 \(name)"
        case .waitingApproval: return "等待审批"
        }
    }

    var color: Color {
        switch self {
        case .inactive: return .gray
        case .idle: return .secondary
        case .working: return .green
        case .callingTool: return .blue
        case .waitingApproval: return .orange
        }
    }

    var iconName: String {
        switch self {
        case .inactive: return "circle"
        case .idle: return "circle.fill"
        case .working: return "circle.fill"
        case .callingTool: return "gear"
        case .waitingApproval: return "exclamationmark.circle.fill"
        }
    }
}

@Observable
final class AppState {
    var sessionActive = false
    var status: SessionStatus = .inactive
    var sessionId: String?

    var contextPercentage: Double = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var contextWindowSize: Int = 0
    var totalCostUSD: Double = 0
    var model: String = ""
    var modelDisplay: String = ""

    var sessionStartTime: Date?
    var toolCallCount: Int = 0
    var toolHistory: [ToolHistoryEntry] = []

    var rateLimitFiveHour: Double?
    var rateLimitSevenDay: Double?

    var pendingApproval: ApprovalRequest?
    var projectDir: String?
    var gitBranch: String?

    var sessionDurationFormatted: String {
        guard let start = sessionStartTime else { return "--" }
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    func updateFromStatusLine(_ data: StatusLineData) {
        if let sid = data.sessionId {
            sessionId = sid
            if !sessionActive {
                sessionActive = true
                sessionStartTime = Date()
            }
        }
        if let m = data.model {
            model = m.id ?? ""
            modelDisplay = m.displayName ?? model
        }
        if let ctx = data.contextWindow {
            contextPercentage = ctx.usedPercentage ?? 0
            inputTokens = ctx.totalInputTokens ?? 0
            outputTokens = ctx.totalOutputTokens ?? 0
            contextWindowSize = ctx.contextWindowSize ?? 0
        }
        if let c = data.cost {
            totalCostUSD = c.totalCostUsd ?? 0
        }
        if let rl = data.rateLimits {
            rateLimitFiveHour = rl.fiveHour?.usedPercentage
            rateLimitSevenDay = rl.sevenDay?.usedPercentage
        }
        if let ws = data.workspace {
            projectDir = ws.projectDir ?? ws.currentDir
            gitBranch = ws.gitWorktree
        }
        if status == .inactive {
            status = .idle
        }
    }

    func handleHookEvent(_ event: HookEvent) {
        guard let eventName = event.hookEventName else { return }

        if let sid = event.sessionId, sessionId == nil {
            sessionId = sid
            sessionActive = true
            sessionStartTime = sessionStartTime ?? Date()
        }

        switch eventName {
        case "PreToolUse":
            let toolName = event.toolName ?? "Unknown"
            status = .callingTool(toolName)
            toolCallCount += 1
            let entry = ToolHistoryEntry(
                name: toolName,
                detail: event.toolInput?.displaySummary ?? "",
                timestamp: Date()
            )
            toolHistory.insert(entry, at: 0)
            if toolHistory.count > 20 {
                toolHistory.removeLast()
            }

        case "PostToolUse", "PostToolUseFailure":
            if case .callingTool = status {
                status = .working
            }

        case "Stop":
            status = .idle

        case "SessionStart":
            sessionActive = true
            status = .working
            sessionStartTime = Date()
            toolCallCount = 0
            toolHistory.removeAll()

        case "SessionEnd":
            sessionActive = false
            status = .inactive
            sessionId = nil

        case "Notification":
            break

        default:
            break
        }
    }

    func resetSession() {
        sessionActive = false
        status = .inactive
        sessionId = nil
        contextPercentage = 0
        inputTokens = 0
        outputTokens = 0
        contextWindowSize = 0
        totalCostUSD = 0
        model = ""
        modelDisplay = ""
        sessionStartTime = nil
        toolCallCount = 0
        toolHistory.removeAll()
        rateLimitFiveHour = nil
        rateLimitSevenDay = nil
        pendingApproval = nil
        projectDir = nil
        gitBranch = nil
    }
}
