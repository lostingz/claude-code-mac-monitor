import SwiftUI

struct MenuBarPopover: View {
    let appState: AppState
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            if appState.sessionActive {
                activeView
            } else {
                inactiveView
            }
        }
        .frame(width: 340)
        .background(Color.techBg)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Active Session

    private var activeView: some View {
        VStack(spacing: 0) {
            headerBar
            techDivider

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    gaugeSection
                    metricsCard
                    if appState.rateLimitFiveHour != nil || appState.rateLimitSevenDay != nil {
                        rateLimitCard
                    }
                    if !appState.toolHistory.isEmpty {
                        toolLogCard
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            techDivider
            footerBar
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.techCyan)
                .shadow(color: .techCyan.opacity(0.5), radius: 4)
            Text("CLAUDE CODE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .kerning(1.5)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(appState.status.color)
                .frame(width: 6, height: 6)
                .shadow(color: appState.status.color.opacity(0.6), radius: 3)
                .opacity(pulseOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        pulseOpacity = 0.3
                    }
                }
            Text(appState.status.label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(appState.status.color)
                .kerning(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(appState.status.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(appState.status.color.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - Gauge

    private var gaugeSection: some View {
        ContextGaugeView(
            percentage: appState.contextPercentage,
            inputTokens: appState.inputTokens,
            outputTokens: appState.outputTokens,
            windowSize: appState.contextWindowSize
        )
        .frame(height: 80)
        .padding(12)
        .background(Color.techCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.techBorder, lineWidth: 0.5))
    }

    // MARK: - Metrics

    private var metricsCard: some View {
        TechCard(title: "METRICS") {
            VStack(spacing: 6) {
                metricRow(label: "INPUT", value: formatTokens(appState.inputTokens), unit: "tokens")
                metricRow(label: "OUTPUT", value: formatTokens(appState.outputTokens), unit: "tokens")
                metricRow(label: "COST", value: String(format: "$%.4f", appState.totalCostUSD), unit: "usd")
                metricRow(label: "TIME", value: appState.sessionDurationFormatted, unit: "elapsed")
                metricRow(label: "TOOLS", value: "\(appState.toolCallCount)", unit: "calls")
            }
        }
    }

    private func metricRow(label: String, value: String, unit: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.techCyan.opacity(0.6))
                .kerning(1)
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text("  \u{25B8} ")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.15))
            Text(unit)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
                .frame(width: 50, alignment: .leading)
        }
    }

    // MARK: - Rate Limits

    private var rateLimitCard: some View {
        TechCard(title: "RATE LIMITS") {
            VStack(spacing: 8) {
                if let fiveHour = appState.rateLimitFiveHour {
                    rateLimitBar(label: "5H", percentage: fiveHour)
                }
                if let sevenDay = appState.rateLimitSevenDay {
                    rateLimitBar(label: "7D", percentage: sevenDay)
                }
            }
        }
    }

    private func rateLimitBar(label: String, percentage: Double) -> some View {
        let barColor: Color = percentage > 80 ? .techRed : percentage > 50 ? .techOrange : .techGreen

        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.techCyan.opacity(0.5))
                .frame(width: 20, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.7), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(CGFloat(percentage / 100) * geo.size.width, 2))
                        .shadow(color: barColor.opacity(0.3), radius: 2)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f%%", percentage))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(barColor)
                .frame(width: 35, alignment: .trailing)
        }
    }

    // MARK: - Tool Log

    private var toolLogCard: some View {
        TechCard(title: "TOOL LOG") {
            VStack(spacing: 4) {
                ForEach(appState.toolHistory.prefix(6)) { entry in
                    HStack(spacing: 6) {
                        Text(formatTime(entry.timestamp))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.techGreen.opacity(0.5))
                        Text(entry.name)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.techCyan.opacity(0.8))
                            .frame(width: 50, alignment: .leading)
                        Text(entry.detail)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 6) {
            if !appState.modelDisplay.isEmpty {
                Text(appState.modelDisplay.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            if appState.projectDir != nil || !appState.modelDisplay.isEmpty {
                Text("|")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.1))
            }
            if let dir = appState.projectDir {
                Text(URL(fileURLWithPath: dir).lastPathComponent)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            Spacer()
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("QUIT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                    .kerning(1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Inactive

    private var inactiveView: some View {
        VStack(spacing: 0) {
            headerBar
            techDivider
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 2)
                        .frame(width: 60, height: 60)
                    Image(systemName: "power")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.white.opacity(0.15))
                }

                VStack(spacing: 4) {
                    Text("NO ACTIVE SESSION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .kerning(2)
                    Text("Waiting for Claude Code...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
            techDivider
            footerBar
        }
    }

    // MARK: - Helpers

    private var techDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.techCyan.opacity(0), .techCyan.opacity(0.2), .techCyan.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 0.5)
            .shadow(color: .techCyan.opacity(0.15), radius: 2)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Tech Card Component

struct TechCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.techCyan.opacity(0.4))
                    .frame(width: 2, height: 8)
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.techCyan.opacity(0.5))
                    .kerning(2)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.techCyan.opacity(0.15), .techCyan.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
            }
            content
        }
        .padding(10)
        .background(Color.techCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.techBorder, lineWidth: 0.5)
        )
    }
}
