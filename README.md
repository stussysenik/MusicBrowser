<div align="center">

# MusicBrowser

![Demo](demo.gif)


### A refined music browser for iOS & macOS

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-007AFF?style=flat-square&logo=apple)
![MusicKit](https://img.shields.io/badge/MusicKit-API-FC3C44?style=flat-square&logo=apple-music&logoColor=white)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-34C759?style=flat-square)
![CloudKit](https://img.shields.io/badge/CloudKit-Sync-5856D6?style=flat-square&logo=icloud&logoColor=white)

Browse your Apple Music library, search the catalog, manage playlists,
and control playback — all from a native SwiftUI interface with
synced lyrics, annotations, and iCloud sync.

</div>

---

## Features

### Library
- **A-Z section index rail** with haptic feedback for fast navigation
- Songs, Albums, Playlists, Artists tabs with ZStack-based preservation
- Context menus: Play, Play Next, Add to Queue, Add to Playlist

### Playlist Management
- Create new playlists directly from the Playlists tab
- Add any song to a playlist via long-press context menu

### Now Playing
- Full playback controls with backward/forward skip
- Synced lyrics display with auto-scroll
- Queue management and shuffle/repeat modes

### Browse & Search
- Apple Music catalog search with scope switching (Songs, Albums, Artists, Playlists)
- Discover view with Apple Music charts
- Album, artist, and playlist detail views with shuffle play

### Annotations & Sync
- Tag, rate, and annotate songs with SwiftData
- iCloud sync via CloudKit container

---

## Getting Started

1. Open `MusicBrowser.xcodeproj` in Xcode 15+
2. Set your development team in Signing & Capabilities
3. Provision the iCloud container in the Apple Developer Portal (for sync)
4. Build and run the `MusicBrowser` scheme

> An Apple Music subscription is required for catalog search and playback features.

---

## Architecture

All services use `@Observable` and are injected via SwiftUI `.environment()` from the app entry point.

| Layer | Path | Purpose |
|-------|------|---------|
| **App** | `MusicBrowser/App/` | Entry point, auth, content shell |
| **Features** | `MusicBrowser/Features/` | Browse, Library, NowPlaying, Search |
| **Services** | `MusicBrowser/Services/` | MusicService, PlayerService, LyricsService, AnnotationService |
| **Shared** | `MusicBrowser/Shared/` | Reusable UI components and utilities |
| **Models** | `MusicBrowser/Models/` | SwiftData models (SongAnnotation) |

---

## Requirements

- iOS 17+ / macOS 14+
- Xcode 15+
- Apple Music subscription (for catalog features)
- iCloud container for sync (provisioned in dev portal)

---

<div align="center">
<sub>Built with SwiftUI + MusicKit</sub>
</div>
