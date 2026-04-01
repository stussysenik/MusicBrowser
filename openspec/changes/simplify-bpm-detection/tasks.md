# Tasks: Simplify BPM Detection

## Phase 1: Remove Microphone Path

### 1.1 Strip MicTapProvider from AudioBufferProvider.swift
- [x] Remove `MicTapProvider` struct entirely
- [x] Remove `SampleAccumulator` class
- [x] Remove mic-related `AudioBufferError` cases (`.microphoneNotAvailable`, `.microphonePermissionDenied`, `.timeout`)
- [x] Keep: `AudioSamples`, `AudioBufferProvider` protocol, `AssetReaderProvider`, `MediaQueryHelper`

### 1.2 Remove mic and live detection from BPMDetectionService.swift
- [x] Remove `detectFromMicrophone()` method
- [x] Remove `startLiveDetection(onUpdate:)` method
- [x] Remove `stopLiveDetection()` method
- [x] Remove `liveTask` property
- [x] Simplify `detectBPM()`: cascade metadata → assetReader only

### 1.3 Remove live state from AnalysisService.swift
- [x] Remove: `liveBPM`, `liveBPMConfidence`, `liveBPMSource`, `isAnalyzingBPM`, `liveBPMTask`
- [x] Remove: `startLiveBPMDetection()`, `stopLiveBPMDetection()`
- [x] Simplify `analyzeBatch()`: inline metadata-only lookup (no detectBPM call)
- [x] Keep: `bpm(for:)`, `cachedAnalysis(for:)`, `analyzeBatch()`, `configure(with:)`, cache

## Phase 2: Simplify UI

### 2.1 Update NowPlayingView.swift
- [x] Remove `.onAppear { analysis.startLiveBPMDetection(...) }`
- [x] Remove `.onDisappear { analysis.stopLiveBPMDetection() }`
- [x] Remove `.onChange(of: player.currentSongID)` live detection re-trigger
- [x] Pass `analysisService.bpm(for:)` directly to LiveBPMView

### 2.2 Simplify LiveBPMView.swift
- [x] Remove `@Environment(AnalysisService.self)` — accept `bpm: Double?` parameter
- [x] Remove `isAnalyzingBPM` / ProgressView / "Analyzing tempo..." state
- [x] Remove confidence dot and source label (unnecessary complexity)
- [x] Show: BPM number + BeatPulseView when bpm > 0, nothing otherwise

### 2.3 Remove NSMicrophoneUsageDescription from Info.plist
- [x] Delete the `NSMicrophoneUsageDescription` key/value pair

## Phase 3: Verify

### 3.1 Build iOS target
- [x] `xcodebuild build` — zero errors

### 3.2 Run on device
- [ ] Open Library — batch analysis completes instantly (metadata-only)
- [ ] Open NowPlaying — BPM shows if cached, no spinner
- [ ] No microphone permission prompt
- [ ] No crashes
