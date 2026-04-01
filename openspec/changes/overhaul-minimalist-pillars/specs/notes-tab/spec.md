# Notes Tab

## ADDED Requirements

### Requirement: Dedicated Notes tab in bottom navigation
A "Notes" tab MUST appear between Library and Search in the bottom TabView, showing all annotated songs sorted by most recently updated.

#### Scenario: Notes tab shows annotated songs
Given the user has annotated 3 songs with notes/ratings/tags
When they tap the Notes tab
Then all 3 annotations appear sorted by updatedAt descending with title, artist, note preview, rating, and relative time

#### Scenario: Empty notes state
Given the user has no annotations
When they tap the Notes tab
Then a ContentUnavailableView with "No Notes" message appears

### Requirement: Search within notes
The Notes tab MUST include a searchable modifier that filters annotations by title, artist, notes content, and tags.

#### Scenario: Search by note content
Given the user has an annotation with notes containing "great bass line"
When they search "bass"
Then that annotation appears in the filtered results

### Requirement: Navigation from notes to song detail
Tapping an annotation in the Notes tab MUST resolve the MusicKit Song by ID and navigate to SongDetailView.

#### Scenario: Navigate to song detail
Given the user taps an annotation in the Notes tab
When the song is resolved via MusicLibraryRequest
Then SongDetailView appears for that song

## MODIFIED Requirements

### Requirement: Tab structure is Library | Notes | Search
The ContentView TabView MUST change from 2 tabs to 3 tabs.

#### Scenario: Three tabs visible
Given the app is launched and authorized
When the main view appears
Then Library, Notes, and Search tabs are visible in the bottom bar
