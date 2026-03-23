import SwiftUI

/// BPM display for the Now Playing screen.
///
/// Shows the cached BPM with a pulsing beat indicator when available.
/// If no BPM is cached, shows nothing — no spinners, no loading state.
struct LiveBPMView: View {
    let bpm: Double?

    var body: some View {
        if let bpm, bpm > 0 {
            HStack(alignment: .center, spacing: 10) {
                Text("\(Int(bpm))")
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)

                BeatPulseView(bpm: bpm)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.easeInOut(duration: 0.3), value: bpm)
        }
    }
}

#Preview("Live BPM") {
    LiveBPMView(bpm: 120)
}
