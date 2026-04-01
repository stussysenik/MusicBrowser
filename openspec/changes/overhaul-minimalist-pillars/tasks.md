# Tasks

## Phase 1: Bug Fixes
- [x] 1.1 Fix gradient stop ordering in ShimmerView.swift
- [x] 1.2 Fix subscription status hang in MusicService.swift (cache + prefetch)
- [x] 1.3 Fix CoreData Array<String> fault in SongAnnotation.swift (tags → tagsRaw)

## Phase 2: Dead Code Removal
- [ ] 2.1 Delete 6 files: FilterPresetService, LyricsService, LyricsView, LibraryAlbumsView, LibraryArtistsView, LibraryPlaylistsView
- [ ] 2.2 Update MusicBrowserApp.swift (remove presetService, lyricsService)
- [ ] 2.3 Update PreviewHost.swift (remove presetService, lyricsService)
- [ ] 2.4 Update NowPlayingView.swift (remove lyrics)
- [ ] 2.5 Update SongDetailView.swift (remove lyricsIndicator)
- [ ] 2.6 Simplify LibraryView.swift (songs-only, remove segmented picker)
- [ ] 2.7 Update pbxproj (remove 6 file entries)

## Phase 3: A-Z Drag-to-Scrub
- [ ] 3.1 Rewrite SectionIndexRail.swift (DragGesture + GeometryReader + bubble)

## Phase 4: Notes Tab
- [ ] 4.1 Add MusicService.librarySong(byID:)
- [ ] 4.2 Create NotesView.swift
- [ ] 4.3 Update ContentView.swift (3 tabs: Library | Notes | Search)

## Phase 5: BPM Audio Analysis
- [ ] 5.1 Create BPMDetectionEngine.swift (Accelerate vDSP DSP)
- [ ] 5.2 Create AudioBufferProvider.swift (AssetReader + MicTap)
- [ ] 5.3 Create BPMDetectionService.swift (cascade orchestrator)
- [ ] 5.4 Modify AnalysisService.swift (integrate cascade + live BPM)
- [ ] 5.5 Extend SongAnalysis.swift (bpmSource, bpmConfidence)
- [ ] 5.6 Add PlayerService.onSongChanged hook
- [ ] 5.7 Create BPMBadgeView.swift, BeatPulseView.swift, LiveBPMView.swift
- [ ] 5.8 Update NowPlayingView.swift (add LiveBPMView)
- [ ] 5.9 Update TrackRow.swift (optional BPM badge)
- [ ] 5.10 Add NSMicrophoneUsageDescription + entitlement

## Phase 6: pbxproj
- [ ] 6.1 Add 7 new file entries to project.pbxproj

## Phase 7: Verification
- [ ] 7.1 Build verification
- [ ] 7.2 Create Maestro E2E tests

## Phase 8: Review
- [ ] 8.1 Validator agent loop
- [ ] 8.2 Minifier agent loop
