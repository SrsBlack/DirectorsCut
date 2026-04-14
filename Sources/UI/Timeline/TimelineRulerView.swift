#if canImport(UIKit)
import SwiftUI

/// Time ruler showing time markers above the timeline.
struct TimelineRulerView: View {
    let duration: Double
    let pixelsPerSecond: Double
    let scrollOffset: CGFloat

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let totalWidth = duration * pixelsPerSecond
                let interval = tickInterval(for: pixelsPerSecond)

                var time: Double = 0
                while time <= duration {
                    let x = time * pixelsPerSecond
                    guard x < totalWidth + 100 else { break }

                    let isMajor = time.truncatingRemainder(dividingBy: interval.major) < 0.01

                    // Draw tick mark
                    let tickHeight: CGFloat = isMajor ? 12 : 6
                    let tickRect = CGRect(
                        x: x, y: size.height - tickHeight,
                        width: 1, height: tickHeight
                    )
                    context.fill(Path(tickRect), with: .color(.secondary.opacity(0.5)))

                    // Draw time label for major ticks
                    if isMajor {
                        let label = formatTime(time)
                        let text = Text(label)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        context.draw(
                            context.resolve(text),
                            at: CGPoint(x: x + 4, y: size.height - tickHeight - 8),
                            anchor: .leading
                        )
                    }

                    time += interval.minor
                }
            }
            .frame(width: max(duration * pixelsPerSecond + 100, geo.size.width))
        }
        .background(Color(uiColor: .tertiarySystemBackground))
    }

    private struct TickInterval {
        let major: Double
        let minor: Double
    }

    private func tickInterval(for pps: Double) -> TickInterval {
        if pps > 200 { return TickInterval(major: 1, minor: 0.1) }
        if pps > 100 { return TickInterval(major: 5, minor: 1) }
        if pps > 50  { return TickInterval(major: 10, minor: 2) }
        if pps > 25  { return TickInterval(major: 30, minor: 5) }
        return TickInterval(major: 60, minor: 10)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if seconds < 60 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
#endif
