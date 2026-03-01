import SwiftUI
import MusicKit

struct AuthorizationView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Apple Music", systemImage: "music.note")
        } description: {
            Text("MusicBrowser needs access to Apple Music to browse and play your library.")
        } actions: {
            Button("Request Access") {
                Task {
                    _ = await MusicAuthorization.request()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Open Settings") {
                openSettings()
            }
        }
    }

    private func openSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
