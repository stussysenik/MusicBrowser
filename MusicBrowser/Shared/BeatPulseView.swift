import SwiftUI

/// A pulsing circle that animates at the detected tempo.
///
/// The circle scales from 1.0 to 1.4 and back with each "beat",
/// creating a visual metronome effect synced to the BPM. The animation
/// interval is derived from `60.0 / bpm` — one full pulse per beat.
struct BeatPulseView: View {
    let bpm: Double

    @State private var isPulsing = false

    /// Duration of one beat in seconds (60 / BPM).
    private var beatInterval: Double {
        guard bpm > 0 else { return 1.0 }
        return 60.0 / bpm
    }

    var body: some View {
        Circle()
            .fill(.orange)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .animation(
                .easeInOut(duration: beatInterval / 2)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
            .onDisappear { isPulsing = false }
    }
}

#Preview("Beat Pulse") {
    HStack(spacing: 24) {
        VStack {
            BeatPulseView(bpm: 60)
            Text("60 BPM").font(.caption)
        }
        VStack {
            BeatPulseView(bpm: 120)
            Text("120 BPM").font(.caption)
        }
        VStack {
            BeatPulseView(bpm: 180)
            Text("180 BPM").font(.caption)
        }
    }
    .padding()
}
