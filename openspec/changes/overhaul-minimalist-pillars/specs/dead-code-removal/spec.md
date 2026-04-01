# Dead Code Removal

## REMOVED Requirements

### Requirement: FilterPresetService
The unused alphabet filter preset service MUST be removed from the codebase and environment injection.

#### Scenario: App launches without FilterPresetService
Given FilterPresetService.swift is deleted
When the app launches
Then no FilterPresetService is injected and no compilation errors occur

### Requirement: LyricsService and LyricsView
The lyrics service and view MUST be removed. No lyrics UI SHALL remain in NowPlayingView or SongDetailView.

#### Scenario: NowPlaying has no lyrics button
Given LyricsService and LyricsView are deleted
When the user opens NowPlayingView
Then no lyrics button or sheet is present

### Requirement: Library sub-views (Albums, Artists, Playlists)
The three library tab views MUST be removed. LibraryView SHALL show songs directly without a segmented picker.

#### Scenario: Library shows songs only
Given LibraryAlbumsView, LibraryArtistsView, LibraryPlaylistsView are deleted
When the user opens the Library tab
Then they see the song list directly with no tab picker
