import Foundation
import MusicKit
import Combine
import MediaPlayer
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PlaybackQueueItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let artwork: Artwork?
}

@Observable
final class PlayerService {
    let runtime: AppRuntime

    private var musicPlayer: ApplicationMusicPlayer?
    private var didConfigureMusicPlayer = false
    #if os(iOS)
    private var localDemoPlayer: MPMusicPlayerApplicationController?
    private var didConfigureLocalDemoPlayer = false
    #endif
    private var cancellables = Set<AnyCancellable>()
    private var timerTask: Task<Void, Never>?
    private let recentRandomHistoryLimit = 12

    private var recentRandomSongIDs: [MusicItemID] = []
    private var demoRecentRandomSongIDs: [String] = []
    private var demoQueue: [DemoSong] = []
    private var demoCurrentIndex = 0

    // MARK: - Observable State

    var isPlaying = false
    var playbackTime: TimeInterval = 0
    var currentDuration: TimeInterval = 0
    var currentTitle: String?
    var currentArtist: String?
    var currentArtwork: Artwork?
    var currentSong: Song?
    var currentSongID: MusicItemID?
    var currentDemoSong: DemoSong?
    var currentTrackID: String?
    var hasLyrics = false
    var shuffleIsOn = false
    var repeatMode: MusicKit.MusicPlayer.RepeatMode = .none

    // MARK: - Queue State

    var queueEntries: [ApplicationMusicPlayer.Queue.Entry] = []
    var currentQueueEntry: ApplicationMusicPlayer.Queue.Entry?
    private(set) var upcomingCache: [ApplicationMusicPlayer.Queue.Entry] = []
    var playbackQueueItems: [PlaybackQueueItem] = []
    var currentPlaybackItem: PlaybackQueueItem?
    var currentPlaybackIndex: Int?

    var isDemoMode: Bool { runtime.usesDummyData }
    private var usesDeviceBackedDemoQueue: Bool {
        runtime.usesDummyData && demoQueue.contains(where: \.isDeviceMediaItem)
    }
    var upcomingEntries: [ApplicationMusicPlayer.Queue.Entry] { upcomingCache }
    var upcomingPlaybackItems: [PlaybackQueueItem] {
        guard let currentPlaybackIndex else { return playbackQueueItems }
        let nextIndex = currentPlaybackIndex + 1
        guard nextIndex < playbackQueueItems.count else { return [] }
        return Array(playbackQueueItems[nextIndex...])
    }

    // MARK: - Init

    init(runtime: AppRuntime = .current) {
        self.runtime = runtime
    }

    deinit {
        timerTask?.cancel()
        #if os(iOS)
        localDemoPlayer?.endGeneratingPlaybackNotifications()
        #endif
    }

    // MARK: - Timer

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

    @discardableResult
    private func ensureMusicPlayer() -> ApplicationMusicPlayer? {
        guard !runtime.usesDummyData else { return nil }
        guard MusicAuthorization.currentStatus == .authorized else { return nil }

        if musicPlayer == nil {
            musicPlayer = ApplicationMusicPlayer.shared
        }

        guard let musicPlayer else { return nil }
        guard !didConfigureMusicPlayer else { return musicPlayer }

        musicPlayer.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncState() }
            .store(in: &cancellables)

        musicPlayer.queue.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncQueue()
            }
            .store(in: &cancellables)

        didConfigureMusicPlayer = true
        syncState()
        syncQueue()
        return musicPlayer
    }

    #if os(iOS)
    @discardableResult
    private func ensureLocalDemoPlayer() -> MPMusicPlayerApplicationController? {
        guard runtime.usesDummyData else { return nil }

        if localDemoPlayer == nil {
            localDemoPlayer = MPMusicPlayerController.applicationQueuePlayer
        }

        guard let localDemoPlayer else { return nil }
        guard !didConfigureLocalDemoPlayer else { return localDemoPlayer }

        localDemoPlayer.beginGeneratingPlaybackNotifications()
        NotificationCenter.default.publisher(
            for: NSNotification.Name.MPMusicPlayerControllerPlaybackStateDidChange,
            object: localDemoPlayer
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.syncLocalDemoPlayerState()
        }
        .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSNotification.Name.MPMusicPlayerControllerNowPlayingItemDidChange,
            object: localDemoPlayer
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.syncLocalDemoPlayerState()
        }
        .store(in: &cancellables)

        didConfigureLocalDemoPlayer = true
        syncLocalDemoPlayerState()
        return localDemoPlayer
    }

    private func syncLocalDemoPlayerState() {
        guard let localDemoPlayer else { return }

        let wasPlaying = isPlaying
        isPlaying = localDemoPlayer.playbackState == .playing
        shuffleIsOn = localDemoPlayer.shuffleMode != .off
        repeatMode = musicKitRepeatMode(for: localDemoPlayer.repeatMode)

        if let item = localDemoPlayer.nowPlayingItem {
            let persistentID = UInt64(item.persistentID)
            if let index = demoQueue.firstIndex(where: { $0.mediaPersistentID == persistentID }) {
                demoCurrentIndex = index
            } else if let nowPlayingSong = DemoSong(mediaItem: item) {
                demoQueue = [nowPlayingSong]
                demoCurrentIndex = 0
            }
        }

        syncDemoQueueState()

        if let duration = localDemoPlayer.nowPlayingItem?.playbackDuration, duration > 0 {
            currentDuration = duration
        }
        playbackTime = max(0, localDemoPlayer.currentPlaybackTime)

        if isPlaying && !wasPlaying {
            startProgressTimer()
        } else if !isPlaying && wasPlaying {
            stopProgressTimer()
        }
    }

    private func localDemoMediaItems(for songs: [DemoSong]) -> [MPMediaItem]? {
        let items = songs.compactMap { song -> MPMediaItem? in
            guard let persistentID = song.mediaPersistentID else { return nil }
            return MediaQueryHelper.findMediaItem(persistentID: persistentID)
        }
        guard items.count == songs.count else { return nil }
        return items
    }

    @discardableResult
    private func playLocalDemoSongsIfPossible(_ songs: [DemoSong], startingAt index: Int) -> Bool {
        guard let items = localDemoMediaItems(for: songs),
              let localDemoPlayer = ensureLocalDemoPlayer(),
              !items.isEmpty else {
            return false
        }

        demoQueue = songs
        demoCurrentIndex = max(0, min(index, songs.count - 1))
        playbackTime = 0
        currentArtwork = nil

        let descriptor = MPMusicPlayerMediaItemQueueDescriptor(
            itemCollection: MPMediaItemCollection(items: items)
        )
        descriptor.startItem = items[demoCurrentIndex]

        localDemoPlayer.setQueue(with: descriptor)
        localDemoPlayer.shuffleMode = .off
        localDemoPlayer.play()
        syncLocalDemoPlayerState()
        return true
    }

    @discardableResult
    private func enqueueLocalDemoSongs(_ songs: [DemoSong], afterCurrent: Bool) -> Bool {
        guard usesDeviceBackedDemoQueue,
              let items = localDemoMediaItems(for: songs),
              let localDemoPlayer = ensureLocalDemoPlayer(),
              !items.isEmpty else {
            return false
        }

        let descriptor = MPMusicPlayerMediaItemQueueDescriptor(
            itemCollection: MPMediaItemCollection(items: items)
        )

        if afterCurrent {
            localDemoPlayer.perform(
                queueTransaction: { queue in
                    queue.insert(descriptor, after: localDemoPlayer.nowPlayingItem)
                },
                completionHandler: { _, _ in }
            )
        } else {
            localDemoPlayer.append(descriptor)
        }
        return true
    }

    private func mpRepeatMode(for mode: MusicKit.MusicPlayer.RepeatMode) -> MPMusicRepeatMode {
        switch mode {
        case .all:
            return .all
        case .one:
            return .one
        default:
            return .none
        }
    }

    private func musicKitRepeatMode(for mode: MPMusicRepeatMode) -> MusicKit.MusicPlayer.RepeatMode {
        switch mode {
        case .all:
            return .all
        case .one:
            return .one
        default:
            return .none
        }
    }
    #endif

    private func syncState() {
        guard let musicPlayer else { return }

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
        guard let musicPlayer else { return }

        let entry = musicPlayer.queue.currentEntry
        currentTitle = entry?.title
        currentArtist = entry?.subtitle
        currentArtwork = entry?.artwork
        currentQueueEntry = entry
        currentDuration = 0
        currentSong = nil
        currentSongID = nil
        currentDemoSong = nil
        currentTrackID = nil
        hasLyrics = false

        if let item = entry?.item {
            switch item {
            case .song(let song):
                currentSong = song
                currentSongID = song.id
                currentTrackID = song.id.rawValue
                currentDuration = song.duration ?? 0
                hasLyrics = song.hasLyrics
            default:
                readDurationFromNowPlaying()
            }
        }

        let entries = Array(musicPlayer.queue.entries)
        queueEntries = entries
        rebuildUpcoming(entries: entries, current: entry)
        syncPlaybackItems(entries: entries, current: entry)
        syncPlaybackTime()
    }

    private func syncPlaybackItems(
        entries: [ApplicationMusicPlayer.Queue.Entry],
        current: ApplicationMusicPlayer.Queue.Entry?
    ) {
        playbackQueueItems = entries.map {
            PlaybackQueueItem(
                id: String(describing: $0.id),
                title: $0.title,
                subtitle: $0.subtitle,
                artwork: $0.artwork
            )
        }

        if let current,
           let currentIndex = entries.firstIndex(where: { $0.id == current.id }),
           currentIndex < playbackQueueItems.count {
            currentPlaybackIndex = currentIndex
            currentPlaybackItem = playbackQueueItems[currentIndex]
        } else {
            currentPlaybackIndex = nil
            currentPlaybackItem = nil
        }
    }

    private func syncDemoQueueState() {
        guard !demoQueue.isEmpty else {
            currentTitle = nil
            currentArtist = nil
            currentArtwork = nil
            currentSong = nil
            currentSongID = nil
            currentDemoSong = nil
            currentTrackID = nil
            currentPlaybackItem = nil
            currentPlaybackIndex = nil
            playbackQueueItems = []
            queueEntries = []
            currentQueueEntry = nil
            upcomingCache = []
            currentDuration = 0
            if !isPlaying {
                playbackTime = 0
            }
            return
        }

        demoCurrentIndex = max(0, min(demoCurrentIndex, demoQueue.count - 1))
        let current = demoQueue[demoCurrentIndex]

        currentTitle = current.title
        currentArtist = current.artistName
        currentArtwork = nil
        currentSong = nil
        currentSongID = nil
        currentDemoSong = current
        currentTrackID = current.id
        hasLyrics = false
        currentDuration = current.duration

        playbackQueueItems = demoQueue.map {
            PlaybackQueueItem(id: $0.id, title: $0.title, subtitle: $0.artistName, artwork: nil)
        }
        currentPlaybackIndex = demoCurrentIndex
        currentPlaybackItem = playbackQueueItems[demoCurrentIndex]

        queueEntries = []
        currentQueueEntry = nil
        upcomingCache = []
    }

    private func rebuildUpcoming(
        entries: [ApplicationMusicPlayer.Queue.Entry],
        current: ApplicationMusicPlayer.Queue.Entry?
    ) {
        guard let current else {
            upcomingCache = entries
            return
        }
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
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue, let localDemoPlayer {
                if let duration = localDemoPlayer.nowPlayingItem?.playbackDuration, duration > 0 {
                    currentDuration = duration
                }
                playbackTime = max(0, localDemoPlayer.currentPlaybackTime)
                return
            }
            #endif
            guard currentTitle != nil else {
                playbackTime = 0
                return
            }

            if isPlaying {
                playbackTime = min(playbackTime + 0.1, currentDuration)
                if currentDuration > 0, playbackTime >= currentDuration {
                    advanceDemoQueueAfterTrackEnd()
                }
            }
            return
        }

        guard let musicPlayer else { return }
        guard isPlaying || currentTitle != nil else {
            playbackTime = 0
            return
        }

        let currentTime = max(0, musicPlayer.playbackTime)
        playbackTime = currentDuration > 0 ? min(currentTime, currentDuration) : currentTime
        if currentDuration <= 0 {
            readDurationFromNowPlaying()
        }
    }

    private func advanceDemoQueueAfterTrackEnd() {
        switch repeatMode {
        case .one:
            playbackTime = 0
        case .all where demoQueue.count > 1:
            demoCurrentIndex = (demoCurrentIndex + 1) % demoQueue.count
            playbackTime = 0
            syncDemoQueueState()
        default:
            guard demoCurrentIndex + 1 < demoQueue.count else {
                isPlaying = false
                stopProgressTimer()
                playbackTime = currentDuration
                return
            }
            demoCurrentIndex += 1
            playbackTime = 0
            syncDemoQueueState()
        }
    }

    private func readDurationFromNowPlaying() {
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let dur = info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval,
           dur > 0 {
            currentDuration = dur
        }
    }

    // MARK: - Playback

    private func syncAfterPlaybackMutation() async {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue {
                syncLocalDemoPlayerState()
                return
            }
            #endif
            syncDemoQueueState()
            return
        }

        syncQueue()
        syncState()
    }

    private func syncAfterQueueMutation() async {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue {
                syncLocalDemoPlayerState()
                return
            }
            #endif
            syncDemoQueueState()
            return
        }

        syncQueue()
    }

    private func playCurrentQueue() async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        try await musicPlayer.play()
        await syncAfterPlaybackMutation()
    }

    private func rememberRandomStart(_ songID: MusicItemID) {
        recentRandomSongIDs.removeAll(where: { $0 == songID })
        recentRandomSongIDs.append(songID)
        if recentRandomSongIDs.count > recentRandomHistoryLimit {
            recentRandomSongIDs.removeFirst(recentRandomSongIDs.count - recentRandomHistoryLimit)
        }
    }

    private func rememberDemoRandomStart(_ songID: String) {
        demoRecentRandomSongIDs.removeAll(where: { $0 == songID })
        demoRecentRandomSongIDs.append(songID)
        if demoRecentRandomSongIDs.count > recentRandomHistoryLimit {
            demoRecentRandomSongIDs.removeFirst(demoRecentRandomSongIDs.count - recentRandomHistoryLimit)
        }
    }

    func play() async throws {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue, let localDemoPlayer = ensureLocalDemoPlayer() {
                localDemoPlayer.play()
                syncLocalDemoPlayerState()
                return
            }
            #endif
            guard currentTitle != nil else { return }
            isPlaying = true
            startProgressTimer()
            return
        }
        try await playCurrentQueue()
    }

    func pause() {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue {
                ensureLocalDemoPlayer()?.pause()
                syncLocalDemoPlayerState()
                return
            }
            #endif
            isPlaying = false
            stopProgressTimer()
            return
        }

        musicPlayer?.pause()
        syncState()
        syncPlaybackTime()
    }

    func togglePlayPause() async throws {
        if isPlaying {
            pause()
        } else {
            try await play()
        }
    }

    func skipForward() async throws {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue {
                ensureLocalDemoPlayer()?.skipToNextItem()
                syncLocalDemoPlayerState()
                return
            }
            #endif
            guard !demoQueue.isEmpty else { return }
            guard demoCurrentIndex + 1 < demoQueue.count || repeatMode == .all else { return }
            demoCurrentIndex = (demoCurrentIndex + 1) % demoQueue.count
            playbackTime = 0
            syncDemoQueueState()
            return
        }

        try await musicPlayer?.skipToNextEntry()
        await syncAfterPlaybackMutation()
    }

    func skipBackward() async throws {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue {
                if let localDemoPlayer = ensureLocalDemoPlayer() {
                    if localDemoPlayer.currentPlaybackTime > 3 {
                        localDemoPlayer.currentPlaybackTime = 0
                    } else {
                        localDemoPlayer.skipToPreviousItem()
                    }
                }
                syncLocalDemoPlayerState()
                return
            }
            #endif
            guard !demoQueue.isEmpty else { return }
            if playbackTime > 3 {
                playbackTime = 0
            } else if demoCurrentIndex > 0 {
                demoCurrentIndex -= 1
                playbackTime = 0
                syncDemoQueueState()
            } else if repeatMode == .all, !demoQueue.isEmpty {
                demoCurrentIndex = demoQueue.count - 1
                playbackTime = 0
                syncDemoQueueState()
            }
            return
        }

        try await musicPlayer?.skipToPreviousEntry()
        await syncAfterPlaybackMutation()
    }

    func seek(to time: TimeInterval) {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue, let localDemoPlayer = ensureLocalDemoPlayer() {
                localDemoPlayer.currentPlaybackTime = time
                syncLocalDemoPlayerState()
                return
            }
            #endif
            playbackTime = min(max(0, time), currentDuration)
            return
        }

        musicPlayer?.playbackTime = time
        syncPlaybackTime()
    }

    // MARK: - Live Queue

    func playSong(_ song: Song) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        musicPlayer.queue = [song]
        try await playCurrentQueue()
    }

    func playSongs(_ songs: [Song], startingAt index: Int = 0) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        guard !songs.isEmpty else { return }
        musicPlayer.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: songs[index])
        try await playCurrentQueue()
    }

    func playAlbum(_ album: Album) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        musicPlayer.queue = [album]
        try await playCurrentQueue()
    }

    func playPlaylist(_ playlist: Playlist) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        musicPlayer.queue = [playlist]
        try await playCurrentQueue()
    }

    @MainActor
    func openMusicVideo(_ video: MusicVideo) {
        guard let url = video.url else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    func playTracks(_ tracks: MusicItemCollection<Track>, startingAt index: Int = 0) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        musicPlayer.queue = ApplicationMusicPlayer.Queue(
            for: tracks,
            startingAt: tracks[tracks.index(tracks.startIndex, offsetBy: index)]
        )
        try await playCurrentQueue()
    }

    func addToQueue(_ song: Song) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        try await musicPlayer.queue.insert(song, position: .tail)
        await syncAfterQueueMutation()
    }

    func playNext(_ song: Song) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        try await musicPlayer.queue.insert(song, position: .afterCurrentEntry)
        await syncAfterQueueMutation()
    }

    func playAlbumShuffled(_ album: Album) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        musicPlayer.state.shuffleMode = .songs
        shuffleIsOn = true
        musicPlayer.queue = [album]
        try await playCurrentQueue()
    }

    func playPlaylistShuffled(_ playlist: Playlist) async throws {
        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }
        musicPlayer.state.shuffleMode = .songs
        shuffleIsOn = true
        musicPlayer.queue = [playlist]
        try await playCurrentQueue()
    }

    // MARK: - Demo Queue

    func playDemoSongs(_ songs: [DemoSong], startingAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        #if os(iOS)
        if playLocalDemoSongsIfPossible(songs, startingAt: index) {
            return
        }
        #endif
        demoQueue = songs
        demoCurrentIndex = max(0, min(index, songs.count - 1))
        playbackTime = 0
        isPlaying = true
        shuffleIsOn = false
        syncDemoQueueState()
        startProgressTimer()
    }

    func playDemoSong(_ song: DemoSong) {
        playDemoSongs([song], startingAt: 0)
    }

    func playDemoAlbum(_ album: DemoAlbum) {
        playDemoSongs(album.songs, startingAt: 0)
    }

    func playDemoAlbumShuffled(_ album: DemoAlbum) {
        let shuffledSongs = album.songs.shuffled()
        guard !shuffledSongs.isEmpty else { return }
        #if os(iOS)
        if playLocalDemoSongsIfPossible(shuffledSongs, startingAt: 0) {
            shuffleIsOn = true
            return
        }
        #endif

        demoQueue = shuffledSongs
        demoCurrentIndex = 0
        playbackTime = 0
        isPlaying = true
        shuffleIsOn = true
        syncDemoQueueState()
        startProgressTimer()
    }

    func addDemoSongToQueue(_ song: DemoSong) {
        #if os(iOS)
        if enqueueLocalDemoSongs([song], afterCurrent: false) {
            if demoQueue.isEmpty {
                demoQueue = [song]
                demoCurrentIndex = 0
            } else {
                demoQueue.append(song)
            }
            syncDemoQueueState()
            return
        }
        #endif
        if demoQueue.isEmpty {
            demoQueue = [song]
            demoCurrentIndex = 0
        } else {
            demoQueue.append(song)
        }
        syncDemoQueueState()
    }

    func playDemoNext(_ song: DemoSong) {
        #if os(iOS)
        if enqueueLocalDemoSongs([song], afterCurrent: true) {
            if demoQueue.isEmpty {
                demoQueue = [song]
                demoCurrentIndex = 0
            } else {
                demoQueue.insert(song, at: min(demoCurrentIndex + 1, demoQueue.count))
            }
            syncDemoQueueState()
            return
        }
        #endif
        if demoQueue.isEmpty {
            demoQueue = [song]
            demoCurrentIndex = 0
        } else {
            demoQueue.insert(song, at: min(demoCurrentIndex + 1, demoQueue.count))
        }
        syncDemoQueueState()
    }

    // MARK: - Random

    func playRandomSong(using musicService: MusicService) async throws {
        if runtime.usesDummyData {
            let songs = musicService.demoSongs
            let ids = songs.map(\.id)
            guard let plan = RandomPlaybackPlanner.makePlan(
                ids: ids,
                current: currentTrackID,
                recent: demoRecentRandomSongIDs
            ) else {
                throw PlaybackError.emptyLibrary
            }

            let songByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
            let orderedSongs = plan.orderedIDs.compactMap { songByID[$0] }
            guard !orderedSongs.isEmpty else {
                throw PlaybackError.emptyLibrary
            }

            playDemoSongs(orderedSongs, startingAt: 0)
            rememberDemoRandomStart(plan.startingID)
            return
        }

        let songs = try await musicService.allLibrarySongs(force: true)
        let ids = songs.map(\.id)
        guard let plan = RandomPlaybackPlanner.makePlan(
            ids: ids,
            current: currentSongID,
            recent: recentRandomSongIDs
        ) else {
            throw PlaybackError.emptyLibrary
        }

        let songByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        let orderedSongs = plan.orderedIDs.compactMap { songByID[$0] }
        guard let startingSong = orderedSongs.first else {
            throw PlaybackError.emptyLibrary
        }

        guard let musicPlayer = ensureMusicPlayer() else {
            throw PlaybackError.unavailable
        }

        musicPlayer.state.shuffleMode = .off
        shuffleIsOn = false
        musicPlayer.queue = ApplicationMusicPlayer.Queue(for: orderedSongs, startingAt: startingSong)
        try await playCurrentQueue()
        rememberRandomStart(plan.startingID)
    }

    // MARK: - Shuffle & Repeat

    func toggleShuffle() {
        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue, let localDemoPlayer = ensureLocalDemoPlayer() {
                let newMode: MPMusicShuffleMode = shuffleIsOn ? .off : .songs
                localDemoPlayer.shuffleMode = newMode
                shuffleIsOn = newMode != .off
                return
            }
            #endif
            shuffleIsOn.toggle()
            guard shuffleIsOn, demoQueue.count > 2 else { return }

            let current = demoQueue[demoCurrentIndex]
            let upcoming = demoQueue.enumerated()
                .filter { $0.offset != demoCurrentIndex }
                .map(\.element)
                .shuffled()
            demoQueue = [current] + upcoming
            demoCurrentIndex = 0
            syncDemoQueueState()
            return
        }

        let newMode: MusicKit.MusicPlayer.ShuffleMode = shuffleIsOn ? .off : .songs
        guard let musicPlayer = ensureMusicPlayer() else { return }

        musicPlayer.state.shuffleMode = newMode
        shuffleIsOn = newMode != .off
        syncState()
    }

    func cycleRepeat() {
        let current = repeatMode
        let next: MusicKit.MusicPlayer.RepeatMode
        if current == .all {
            next = .one
        } else if current == .one {
            next = .none
        } else {
            next = .all
        }

        if runtime.usesDummyData {
            #if os(iOS)
            if usesDeviceBackedDemoQueue, let localDemoPlayer = ensureLocalDemoPlayer() {
                localDemoPlayer.repeatMode = mpRepeatMode(for: next)
                repeatMode = next
                return
            }
            #endif
            repeatMode = next
            return
        }

        guard let musicPlayer = ensureMusicPlayer() else { return }

        musicPlayer.state.repeatMode = next
        repeatMode = next
    }

    private enum PlaybackError: LocalizedError {
        case emptyLibrary
        case unavailable

        var errorDescription: String? {
            switch self {
            case .emptyLibrary:
                return "Your library has no songs."
            case .unavailable:
                return "Playback is unavailable until Music access is authorized."
            }
        }
    }
}
