# Simplify BPM Detection

## Summary
Remove live/real-time BPM analysis and microphone-based detection. Replace with a simple one-shot detect-and-cache model: try asset reader first, fall back to metadata, cache permanently. No continuous mic monitoring, no `MicTapProvider`, no `LiveBPMView` spinner states.

## Motivation
The current BPM system has three sources (asset reader DSP, microphone tap, metadata) and two modes (batch and live). This causes:
1. **Startup blocking** — batch analysis with asset reader processes songs sequentially (30s each)
2. **Audio crashes** — `MicTapProvider` format mismatches cause NSExceptions
3. **Poor UX** — "Analyzing tempo..." spinner in NowPlaying while mic records for 15s
4. **Unnecessary complexity** — live BPM monitoring re-runs detection every 15s via mic

The user wants: detect BPM once, fill it in, cache it. No real-time monitoring.

## Scope
- **Remove:** `MicTapProvider`, `startLiveDetection`/`stopLiveDetection`, `LiveBPMView` spinner/analyzing states, all `liveBPM*` observable properties from `AnalysisService`, microphone permission dependency
- **Keep:** `AssetReaderProvider` (reads local audio files), `SpectralFluxBPMEngine` (DSP), `BPMBadgeView` (pill badge), `BeatPulseView` (visual pulse), metadata fallback
- **Simplify:** `AnalysisService` becomes a thin cache layer that runs one-shot detection per song on demand
- **Change NowPlaying:** Show cached BPM instantly (no spinner). If no BPM cached, show nothing or trigger background analysis.

## Impact
- Files to delete: None (simplify in place)
- Files to modify: `BPMDetectionService.swift`, `AudioBufferProvider.swift`, `AnalysisService.swift`, `NowPlayingView.swift`, `LiveBPMView.swift`, `Info.plist` (remove `NSMicrophoneUsageDescription`)
- Files unaffected: `BPMDetectionEngine.swift`, `BPMBadgeView.swift`, `BeatPulseView.swift`, `TrackRow.swift`

## Status
- [ ] Approved
