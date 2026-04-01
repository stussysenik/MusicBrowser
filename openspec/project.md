# MusicBrowser

## Overview
SwiftUI + MusicKit iOS music library browser focused on song discovery, BPM analysis, and personal annotations.

## Stack
- Swift 5.9, SwiftUI, MusicKit, SwiftData
- iOS 17+ / macOS 14+
- @Observable services injected via .environment()
- Xcode project (not SPM workspace)

## Architecture
- Services: MusicService, PlayerService, AnalysisService, AnnotationService
- Features: Library (songs), Notes, Search, NowPlaying, Browse
- Shared: Reusable components (SectionIndexRail, TrackRow, ArtworkView, etc.)
- Models: SongAnalysis, SongAnnotation (SwiftData @Model)

## Principles
- Minimalism: few features done expertly
- Declarative SwiftUI patterns
- Performance: cached computed properties, lazy stacks, O(1) lookups
- Apple Music-quality interaction fidelity
