# Design: Minimalist Overhaul

## Architecture Decisions

### BPM: Pure DSP via Accelerate, not Core ML
A Core ML model for tempo estimation would add 5-50MB to the bundle and require training data. The Accelerate/vDSP approach (onset detection via spectral flux + autocorrelation) is deterministic, zero-bundle-size, hardware-accelerated, and debuggable. A `BPMDetectionEngineProtocol` abstraction allows swapping in an ML model later.

### BPM Audio Source Cascade
1. **AVAssetReader** for DRM-free local files (most accurate, no room acoustics)
2. **AVAudioEngine mic tap** for DRM/streamed content (captures via microphone during playback)
3. **MPMediaItem.beatsPerMinute** metadata as fallback

### Tab Structure: Library | Notes | Search
Replaces the 4-section segmented picker inside Library with a dedicated Notes bottom tab. Library becomes songs-only. This gives annotations first-class citizenship.

### A-Z Rail: DragGesture + GeometryReader
Replaces 27 `Button` instances with a single `DragGesture(minimumDistance: 0)` that maps Y position to letter index via `GeometryReader`. Adaptive letter height fills available space. Floating bubble overlay shows current letter.

## Data Flow

```
Song Library → LibrarySongsView → A-Z Rail (drag gesture → ScrollViewReader.scrollTo)
                                → BPM Badge (AnalysisService.bpm(for:))
                                → Context Menu → SongDetailView → Annotations

NowPlaying → LiveBPMView → AnalysisService.liveBPM (mic tap → DSP → result)
                         → BeatPulseView (animates at detected tempo)

Notes Tab → AnnotationService.allAnnotations() → NotesView → SongDetailView
```

## Files Impact
- 7 new files, 13 modified files, 6 deleted files
- Net LOC change estimated: +800 new, -600 removed = ~+200 net
