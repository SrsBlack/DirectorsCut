#if canImport(UIKit)
import SwiftUI

/// The playhead indicator that shows current time position on the timeline.
struct PlayheadView: View {
    let currentTime: Double
    let pixelsPerSecond: Double
    let height: CGFloat

    private var xPosition: CGFloat {
        CGFloat(currentTime * pixelsPerSecond)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Triangle marker at top
            Triangle()
                .fill(Color.red)
                .frame(width: 14, height: 8)

            // Vertical line
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: height)
        }
        .offset(x: xPosition - 7) // Center the triangle
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
#endif
