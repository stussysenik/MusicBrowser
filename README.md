# MusicBrowser

MusicBrowser is a SwiftUI + MusicKit app for browsing Apple Music library content, searching catalog items, and controlling playback with queue/now-playing views.

## What Changed (March 1, 2026)

- Added `#Preview` blocks across all SwiftUI view files for direct canvas rendering.
- Added a shared preview utility: `MusicBrowser/Shared/PreviewHost.swift`.
- Improved `SongDetailView` safety by removing forced URL unwrap for the lyrics link.

## Development

- Open `MusicBrowser.xcodeproj` in Xcode.
- Build with scheme: `MusicBrowser`.
- SwiftUI previews are now available directly in each view file.
