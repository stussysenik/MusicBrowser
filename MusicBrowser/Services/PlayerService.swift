import Foundation
import MusicKit
import Combine
import MediaPlayer

@Observable
final class PlayerService {
    private let musicPlayer = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()
    private var timerTask: Task<Void, Never>?

    // MARK: - Observable State

    var isPlaying = false
    var playbackTime: TimeInterval = 0
    var currentDuration: TimeInterval = 0
    var currentTitle: String?
    var currentArtist: String?
    var currentArtwork: Artwork?
    var currentSongID: MusicItemID?
    var hasLyrics = false
    var shuffleIsOn = false
    var repeatMode: MusicKit.MusicPlayer.RepeatMode = .none

    // MARK: - Queue State (cached for O(1))

    var queueEntries: [ApplicationMusicPlayer.Queue.Entry] = []
    var currentQueueEntry: ApplicationMusicPlayer.Queue.Entry?
    private(set) var upcomingCache: [ApplicationMusicPlayer.Queue.Entry] = []

    var upcomingEntries: [ApplicationMusicPlayer.Queue.Entry] { upcomingCache }

    // MARK: - Session Callbacks (zero-dependency hooks for StatsService)

    /// Called when a new song starts playing. Parameters: songID, title, artistName, albumTitle, genreNames, duration, releaseYear
    var onSongStarted: ((MusicItemID, String, String, String?, [String], TimeInterval?, Int?) -> Void)?
    /// Called when the current song ends or changes. Parameters: songID, completedFully
    var onSongEnded: ((MusicItemID, Bool) -> Void)?

    private var previousSongID: MusicItemID?

    // MARK: - Init

    init() {
        musicPlayer.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncState() }
            .store(in: &cancellables)

        musicPlayer.queue.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.syncQueue() }
            }
            .store(in: &cancellables)

        syncState()
    }

    deinit { timerTask?.cancel() }

    // MARK: - Timer Management

    private func startProgressTimer() {
        guard timerTask == nil else { return }
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.syncPlaybackTime()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopProgressTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Sync

    private func syncState() {
        let wasPlaying = isPlaying
        isPlaying = musicPlayer.state.playbackStatus == .playing
        shuffleIsOn = (musicPlayer.state.shuffleMode ?? .off) != .off
        repeatMode = musicPlayer.state.repeatMode ?? .none

        if isPlaying && !wasPlaying {
            startProgressTimer()
        } else if !isPlaying && wasPlaying {
            stopProgressTimer()
            syncPlaybackTime()
        }
    }

    private func syncQueue() {
        let entry = musicPlayer.queue.currentEntry
        currentTitle = entry?.title
        currentArtist = entry?.subtitle
        currentArtwork = entry?.artwork
        currentQueueEntry = entry

        // Read duration directly from the current entry's item
        if let item = entry?.item {
            switch item {
            case .song(let song):
                currentDuration = song.duration ?? 0
                currentSongID = song.id
                hasLyrics = song.hasLyrics

                // Fire session callbacks when song changes
                if song.id != previousSongID {
                    // End previous session
                    if let prevID = previousSongID {
                        let completed = playbackTime > 0 && currentDuration > 0 && (playbackTime / currentDuration > 0.9)
                        onSongEnded?(prevID, completed)
                    }
                    // Start new session
                    let year = song.releaseDate?.year
                    onSongStarted?(song.id, song.title, song.artistName, song.albumTitle, song.genreNames, song.duration, year)
                    previousSongID = song.id
                }
            default:
                // Fallback to MPNowPlayingInfoCenter
                readDurationFromNowPlaying()
                // End previous session if switching to non-song
                if let prevID = previousSongID {
                    onSongEnded?(prevID, false)
                    previousSongID = nil
                }
                currentSongID = nil
                hasLyrics = false
            }
        }

        // Cache queue and upcoming in one pass
        let entries = Array(musicPlayer.queue.entries)
        queueEntries = entries
        rebuildUpcoming(entries: entries, current: entry)
    }

    private func rebuildUpcoming(entries: [ApplicationMusicPlayer.Queue.Entry], current: ApplicationMusicPlayer.Queue.Entry?) {
        guard let current else { upcomingCache = entries; return }
        guard let idx = entries.firstIndex(where: { $0.id == current.id }) else {
            upcomingCache = []
            return
        }
        let nextIdx = entries.index(after: idx)
        guard nextIdx < entries.endIndex else {
            upcomingCache = []
            return
        }
        upcomingCache = Array(entries[nextIdx...])
    }

    private func syncPlaybackTime() {
        guard isPlaying || currentTitle != nil else { return }
        playbackTime = musicPlayer.playbackTime

        // If duration wasn't set from queue entry, try MPNowPlayingInfoCenter
        if currentDuration <= 0 {
            readDurationFromNowPlaying()
        }
    }

    private func readDurationFromNowPlaying() {
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let dur = info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval,
           dur > 0 {
            currentDuration = dur
        }
    }

    // MARK: - Playback Controls

    func play() async throws {
        try await musicPlayer.play()
    }

    func pause() {
        musicPlayer.pause()
    }

    func togglePlayPause() async throws {
        if isPlaying { pause() } else { try await play() }
    }

    func skipForward() async throws {
        try await musicPlayer.skipToNextEntry()
    }

    func skipBackward() async throws {
        try await musicPlayer.skipToPreviousEntry()
    }

    func seek(to time: TimeInterval) {
        musicPlayer.playbackTime = time
    }

    // MARK: - Queue

    func playSong(_ song: Song) async throws {
        musicPlayer.queue = [song]
        try await musicPlayer.play()
    }

    func playSongs(_ songs: [Song], startingAt index: Int = 0) async throws {
        guard !songs.isEmpty else { return }
        let safeIndex = min(index, songs.count - 1)
        musicPlayer.queue = ApplicationMusicPlayer.Queue(
            for: songs,
            startingAt: songs[safeIndex]
        )
        try await musicPlayer.play()
    }

    func playSongsShuffled(_ songs: [Song]) async throws {
        guard !songs.isEmpty else { return }
        musicPlayer.state.shuffleMode = .songs
        musicPlayer.queue = ApplicationMusicPlayer.Queue(for: songs)
        try await musicPlayer.play()
    }

    func playAlbum(_ album: Album) async throws {
        musicPlayer.queue = [album]
        try await musicPlayer.play()
    }

    func playPlaylist(_ playlist: Playlist) async throws {
        musicPlayer.queue = [playlist]
        try await musicPlayer.play()
    }

    func playTracks(_ tracks: MusicItemCollection<Track>, startingAt index: Int = 0) async throws {
        guard !tracks.isEmpty else { return }
        let safeIndex = min(index, tracks.count - 1)
        musicPlayer.queue = ApplicationMusicPlayer.Queue(
            for: tracks,
            startingAt: tracks[tracks.index(tracks.startIndex, offsetBy: safeIndex)]
        )
        try await musicPlayer.play()
    }

    // MARK: - Queue Management

    func addToQueue(_ song: Song) async throws {
        try await musicPlayer.queue.insert(song, position: .tail)
    }

    func playNext(_ song: Song) async throws {
        try await musicPlayer.queue.insert(song, position: .afterCurrentEntry)
    }

    // MARK: - Shuffled Play (race-condition-free)

    func playAlbumShuffled(_ album: Album) async throws {
        musicPlayer.state.shuffleMode = .songs
        shuffleIsOn = true
        musicPlayer.queue = [album]
        try await musicPlayer.play()
    }

    func playPlaylistShuffled(_ playlist: Playlist) async throws {
        musicPlayer.state.shuffleMode = .songs
        shuffleIsOn = true
        musicPlayer.queue = [playlist]
        try await musicPlayer.play()
    }

    // MARK: - True Random

    func playRandomSong(using musicService: MusicService) async throws {
        let song = try await musicService.randomLibrarySong()
        musicPlayer.state.shuffleMode = .off
        shuffleIsOn = false
        musicPlayer.queue = [song]
        try await musicPlayer.play()
    }

    // MARK: - Shuffle & Repeat

    func toggleShuffle() {
        let newMode: MusicKit.MusicPlayer.ShuffleMode = shuffleIsOn ? .off : .songs
        musicPlayer.state.shuffleMode = newMode
        shuffleIsOn = newMode != .off
    }

    func cycleRepeat() {
        let current = repeatMode
        let next: MusicKit.MusicPlayer.RepeatMode
        if current == .all {
            next = .one
        } else if current == .one {
            next = MusicKit.MusicPlayer.RepeatMode.none
        } else {
            next = .all
        }
        musicPlayer.state.repeatMode = next
        repeatMode = next
    }
}
