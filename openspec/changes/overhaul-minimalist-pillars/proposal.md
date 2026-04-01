# overhaul-minimalist-pillars

## Summary
Cut MusicBrowser from 4 library tabs to a focused 3-pillar app: Songs (with Apple Music A-Z drag-to-scrub), BPM (real-time audio analysis via Accelerate DSP), and Notes (dedicated annotations workspace). Fix gradient, subscription hang, and CoreData bugs. Remove 6 dead-code files.

## Motivation
The app grew broad without going deep. The A-Z rail is tap-only and doesn't match Apple Music quality. BPM is metadata-only. Annotated songs have no quick access. Runtime bugs (14.5s hang, gradient warnings, CoreData faults) degrade UX. The user wants minimalism: a few things done to expert level.

## Scope
- **In scope:** A-Z rewrite, BPM audio pipeline, Notes tab, bug fixes, dead code removal, Maestro E2E tests
- **Out of scope:** Albums/Artists/Playlists views (being removed), lyrics features (being removed), macOS-specific work

## Capabilities
1. `az-drag-scrub` — Apple Music-style drag-to-scrub section index with haptic feedback and floating bubble
2. `bpm-audio-analysis` — Real-time BPM detection via Accelerate vDSP FFT with AVAssetReader/mic tap cascade
3. `notes-tab` — Dedicated bottom tab for recently annotated songs with search and navigation
4. `bug-fixes` — Gradient stop ordering, subscription status caching, CoreData tags serialization
5. `dead-code-removal` — Remove FilterPresetService, LyricsService, LyricsView, 3 library tab views

## Dependencies
- `bug-fixes` and `dead-code-removal` are independent, do first
- `az-drag-scrub` depends on `dead-code-removal` (LibraryView simplification)
- `notes-tab` depends on `dead-code-removal` (ContentView restructure)
- `bpm-audio-analysis` can proceed in parallel after `dead-code-removal`
