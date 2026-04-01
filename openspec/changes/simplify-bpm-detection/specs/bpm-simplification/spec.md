# BPM Simplification

Cross-references: `bpm-audio-analysis` (supersedes live detection requirements)

## MODIFIED Requirements

### Requirement: BPM detection via one-shot cascade
BPM detection MUST try metadata first (instant), then asset reader (30s DSP). No microphone fallback. Result is cached permanently in SwiftData via `SongAnalysis`.

#### Scenario: Song has MPMediaItem.beatsPerMinute metadata
Given a song in the local library with BPM metadata
When BPM detection runs
Then the metadata BPM is returned immediately with confidence 0.5 and source "metadata"

#### Scenario: Song has local audio file but no metadata
Given a DRM-free song with assetURL but no BPM tag
When BPM detection runs
Then 30s of audio is read via AVAssetReader, processed by SpectralFluxBPMEngine, and the result is returned with source "assetReader"

#### Scenario: Streaming-only song with no metadata
Given a song with no local file and no BPM metadata
When BPM detection runs
Then nil is returned and no BPM is displayed

### Requirement: BPM display in NowPlaying
NowPlaying MUST show cached BPM with BeatPulseView when available. MUST NOT show loading spinners or "Analyzing tempo" text. If BPM is not yet cached, background analysis is triggered and the UI updates when the result arrives.

#### Scenario: Song with cached BPM opens NowPlaying
Given a playing song with BPM cached in SongAnalysis
When the user opens NowPlaying
Then BPM number and BeatPulseView appear immediately

#### Scenario: Song without cached BPM opens NowPlaying
Given a playing song with no cached BPM
When the user opens NowPlaying
Then no BPM section is shown initially
And background analysis runs
And when analysis completes the BPM appears with animation

## REMOVED Requirements

### Requirement: Live BPM detection via microphone
~~BPM detection MUST support continuous microphone-based detection as a fallback.~~
Removed: Microphone-based BPM detection is unreliable and adds unnecessary complexity.

### Requirement: Real-time BPM updates during playback
~~BPM MUST update in real-time during playback via continuous mic sampling.~~
Removed: One-shot detection with caching is sufficient.

### Requirement: Microphone usage description
~~Info.plist MUST include NSMicrophoneUsageDescription.~~
Removed: No microphone access needed.
