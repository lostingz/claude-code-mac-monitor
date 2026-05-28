import SwiftUI

extension Color {
    static let techBg = Color(red: 0.05, green: 0.07, blue: 0.09)
    static let techCyan = Color(red: 0.00, green: 0.83, blue: 1.00)
    static let techGreen = Color(red: 0.00, green: 1.00, blue: 0.53)
    static let techOrange = Color(red: 1.00, green: 0.58, blue: 0.00)
    static let techRed = Color(red: 1.00, green: 0.23, blue: 0.25)
    static let techCard = Color.white.opacity(0.04)
    static let techBorder = Color(red: 0.00, green: 0.83, blue: 1.00).opacity(0.2)
}

struct ContextGaugeView: View {
    let percentage: Double
    let inputTokens: Int
    let outputTokens: Int
    let windowSize: Int

    init(percentage: Double, inputTokens: Int = 0, outputTokens: Int = 0, windowSize: Int = 0) {
        self.percentage = percentage
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.windowSize = windowSize
    }

    private var gaugeColor: Color {
        if percentage > 80 { return .techRed }
        if percentage > 50 { return .techOrange }
        return .techCyan
    }

    var body: some View {
        HStack(spacing: 20) {
            ringGauge
            rightPanel
        }
    }

    private var ringGauge: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let scanAngle = Angle(degrees: now.truncatingRemainder(dividingBy: 3.0) / 3.0 * 360.0)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: min(percentage / 100, 1.0))
                    .stroke(
                        AngularGradient(
                            colors: [gaugeColor.opacity(0.3), gaugeColor],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(percentage / 100 * 360)
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: 0.08)
                    .stroke(gaugeColor.opacity(0.8), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(scanAngle)
                    .shadow(color: gaugeColor.opacity(0.6), radius: 4)

                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 3)
                    .padding(9)

                if windowSize > 0 {
                    let outputRatio = min(Double(outputTokens) / Double(windowSize) * 10, 1.0)
                    Circle()
                        .trim(from: 0, to: outputRatio)
                        .stroke(Color.techGreen.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .padding(9)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 0) {
                    Text(String(format: "%.0f", percentage))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: gaugeColor.opacity(0.5), radius: 6)
                    Text("%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(gaugeColor.opacity(0.7))
                }
            }
            .frame(width: 72, height: 72)
        }
    }

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONTEXT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.techCyan.opacity(0.6))
                .kerning(2)

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [gaugeColor, gaugeColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(CGFloat(percentage / 100) * w, 2), height: 4)
                        .shadow(color: gaugeColor.opacity(0.4), radius: 3)
                }
            }
            .frame(height: 4)

            if windowSize > 0 {
                Text("\(formatTokensShort(inputTokens)) / \(formatTokensShort(windowSize))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(statusMessage)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(gaugeColor.opacity(0.5))
        }
    }

    private var statusMessage: String {
        if percentage > 80 { return "LOW CONTEXT" }
        if percentage > 50 { return "HALF USED" }
        return "NOMINAL"
    }

    private func formatTokensShort(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.0fK", Double(count) / 1000) }
        return "\(count)"
    }
}
