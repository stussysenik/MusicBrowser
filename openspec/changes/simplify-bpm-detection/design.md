# Design: Simplify BPM Detection

## Architecture Before
```
AnalysisService (live state: liveBPM, isAnalyzingBPM, liveBPMTask)
  └── BPMDetectionService
        ├── detectBPM() → cascade: metadata → assetReader → mic
        ├── startLiveDetection() → continuous mic loop every 15s
        └── stopLiveDetection()
              ├── AssetReaderProvider (reads local file via AVAssetReader)
              ├── MicTapProvider (AVAudioEngine mic tap, os_unfair_lock accumulator)
              └── MediaQueryHelper (MPMediaItem.beatsPerMinute)
```

## Architecture After
```
AnalysisService (cache only: [String: SongAnalysis])
  └── BPMDetectionService
        └── detectBPM() → cascade: metadata → assetReader (no mic)
              ├── AssetReaderProvider (unchanged)
              └── MediaQueryHelper (unchanged)
```

## Key Decisions

### 1. Remove MicTapProvider entirely
The mic path is unreliable (format mismatches, permission prompts, 15s capture time). Asset reader + metadata cover all local library songs. Streaming-only songs without metadata simply won't have BPM — acceptable tradeoff.

### 2. Remove live BPM state from AnalysisService
Properties `liveBPM`, `liveBPMConfidence`, `liveBPMSource`, `isAnalyzingBPM`, `liveBPMTask` are all removed. The service becomes a pure cache with on-demand detection.

### 3. NowPlaying shows cached BPM or triggers background analysis
- If BPM is cached: show `BeatPulseView` + BPM number immediately
- If not cached: trigger `analyzeSong` in background, update UI when done via `@Observable` cache change
- No "Analyzing tempo..." spinner — either you see the BPM or you don't yet

### 4. Keep AssetReaderProvider at 30s for accuracy
The spectral flux algorithm needs sufficient audio data. 30s is the right tradeoff for accuracy. Since this only runs once per song (then cached), the cost is amortized.

### 5. Batch analysis stays metadata-only
The current `analyzeBatch(metadataOnly: true)` pattern stays — instant metadata lookup for library browsing. Full DSP analysis runs on-demand when a song is viewed or played.

### 6. Remove NSMicrophoneUsageDescription
No more microphone access needed. Cleaner permission profile.

## Files Changed

| File | Change |
|------|--------|
| `Services/BPMDetectionService.swift` | Remove `startLiveDetection`, `stopLiveDetection`, `detectFromMicrophone`, `metadataOnly`/`skipMicrophone` params. Simplify to `detectBPM(title:artist:) → metadata → assetReader` |
| `Services/AudioBufferProvider.swift` | Remove `MicTapProvider`, `SampleAccumulator`, mic permission code. Keep `AssetReaderProvider`, `MediaQueryHelper`, `AudioSamples`, `AudioBufferError` (minus mic errors) |
| `Services/AnalysisService.swift` | Remove all `liveBPM*` properties, `liveBPMTask`, `startLiveBPMDetection`, `stopLiveBPMDetection`. Add simple `ensureBPM(for:)` that checks cache and triggers background analysis if needed |
| `NowPlaying/NowPlayingView.swift` | Remove `onAppear`/`onDisappear` live detection calls. Use `analysisService.bpm(for:)` directly |
| `Shared/LiveBPMView.swift` | Simplify: show BPM + BeatPulse when available, nothing when not. Remove ProgressView/"Analyzing" state |
| `Info.plist` | Remove `NSMicrophoneUsageDescription` |
