# BPM Audio Analysis

## ADDED Requirements

### Requirement: BPM detection via spectral flux DSP engine
A stateless DSP engine MUST use Accelerate/vDSP to detect tempo from raw audio samples via FFT, spectral flux onset detection, and autocorrelation.

#### Scenario: Analyze DRM-free local audio
Given a song with an accessible assetURL (non-DRM)
When analysis is triggered
Then AVAssetReader reads 30s of audio and the DSP engine returns BPM with confidence score

#### Scenario: Analyze DRM/streamed audio via microphone
Given a song is playing but has no assetURL (DRM-protected)
When analysis is triggered and microphone permission is granted
Then AVAudioEngine captures 15-20s of mic input and the DSP engine returns BPM

#### Scenario: Fallback to metadata
Given neither file analysis nor mic capture produces a result
When the MPMediaItem has a beatsPerMinute value > 0
Then that metadata value is used with confidence 0.5

### Requirement: Live BPM display in NowPlayingView
The NowPlayingView MUST show real-time BPM with a pulsing beat indicator while a song plays.

#### Scenario: Live BPM updates during playback
Given the NowPlayingView is visible and a song is playing
When the analysis service detects BPM changes
Then the displayed BPM number and beat pulse update in real-time

### Requirement: Inline BPM badges in song rows
Song list rows MUST display an orange pill badge showing the cached BPM value when available.

#### Scenario: Song with cached BPM
Given a song has been analyzed and BPM is cached
When the song appears in a list
Then an orange pill badge with the BPM value is shown trailing

## MODIFIED Requirements

### Requirement: SongAnalysis model includes source and confidence
The SongAnalysis SwiftData model MUST store bpmSource (which method detected it) and bpmConfidence (0.0-1.0).

#### Scenario: Analysis result persisted with metadata
Given BPM detection completes via any source
When the result is saved to SwiftData
Then bpmSource and bpmConfidence are stored alongside bpm value
