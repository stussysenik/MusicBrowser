# DOCS

## Architecture Notes

- UI: SwiftUI views under `MusicBrowser/App`, `MusicBrowser/Features`, and `MusicBrowser/Shared`.
- Services: `MusicService`, `PlayerService`, and `AnalysisService` under `MusicBrowser/Services`.
- Model storage: SwiftData model `SongAnalysis`.

## Preview Infrastructure

- `MusicBrowser/Shared/PreviewHost.swift` provides:
  - `PreviewHost`: injects service environments and an in-memory SwiftData container.
  - `PreviewLibraryLoader`: async fetch helpers for previewable `Song`, `Album`, `Artist`, and `Playlist`.
  - `PreviewLibraryItemContainer`: reusable loader wrapper for detail-screen previews.

## Safety / Ergonomics

- `SongDetailView` lyrics deep-link now conditionally builds URL instead of force-unwrapping.
- Added view-local preview entry points for faster iteration and safer UI regression checks.
