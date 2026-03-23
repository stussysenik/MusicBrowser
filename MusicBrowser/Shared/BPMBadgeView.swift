import SwiftUI

/// Small orange pill badge displaying a BPM value.
/// Used in TrackRow and list contexts where space is limited.
///
/// **Design:** Capsule shape with translucent orange fill, bold monospaced digits
/// to prevent layout shifts as the number changes.
struct BPMBadgeView: View {
    let bpm: Double

    var body: some View {
        Text("\(Int(bpm))")
            .font(.caption2.bold().monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(.orange)
    }
}

#Preview("BPM Badge") {
    HStack(spacing: 12) {
        BPMBadgeView(bpm: 72)
        BPMBadgeView(bpm: 120)
        BPMBadgeView(bpm: 180)
    }
    .padding()
}
