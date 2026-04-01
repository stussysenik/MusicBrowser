import Foundation
#if os(iOS)
import MediaPlayer
#endif

struct DemoSong: Identifiable, Hashable, FilterableByLetter {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String
    let duration: TimeInterval
    let genreNames: [String]
    let playCount: Int
    let releaseYear: Int
    let bpm: Double
    let mediaPersistentID: UInt64?
    let albumPersistentID: UInt64?

    var isDeviceMediaItem: Bool {
        mediaPersistentID != nil
    }

    init(
        id: String,
        title: String,
        artistName: String,
        albumTitle: String,
        duration: TimeInterval,
        genreNames: [String],
        playCount: Int,
        releaseYear: Int,
        bpm: Double,
        mediaPersistentID: UInt64? = nil,
        albumPersistentID: UInt64? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.duration = duration
        self.genreNames = genreNames
        self.playCount = playCount
        self.releaseYear = releaseYear
        self.bpm = bpm
        self.mediaPersistentID = mediaPersistentID
        self.albumPersistentID = albumPersistentID
    }

    init(
        _ title: String,
        artist: String,
        album: String = "",
        duration: TimeInterval = 210,
        genres: [String] = ["Pop"],
        plays: Int = 0,
        year: Int = 2024,
        bpm: Double? = nil
    ) {
        self.init(
            id: "\(title)-\(artist)".lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title,
            artistName: artist,
            albumTitle: album.isEmpty ? "\(title) - Single" : album,
            duration: duration,
            genreNames: genres,
            playCount: plays,
            releaseYear: year,
            bpm: bpm ?? Double(78 + abs("\(title)\(artist)".hashValue % 84))
        )
    }

    #if os(iOS)
    init?(mediaItem: MPMediaItem) {
        let resolvedTitle = mediaItem.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resolvedTitle.isEmpty else { return nil }

        let resolvedArtist = mediaItem.artist?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? mediaItem.albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "Unknown Artist"
        let resolvedAlbum = mediaItem.albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "\(resolvedTitle) - Single"
        let resolvedGenres = mediaItem.genre?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty.map { [$0] } ?? ["Unknown"]
        let resolvedYear = mediaItem.releaseDate?.year ?? Calendar.current.component(.year, from: .now)
        let resolvedBPM = mediaItem.beatsPerMinute > 0
            ? Double(mediaItem.beatsPerMinute)
            : Double(78 + abs("\(resolvedTitle)\(resolvedArtist)".hashValue % 84))

        self.init(
            id: "media-\(mediaItem.persistentID)",
            title: resolvedTitle,
            artistName: resolvedArtist,
            albumTitle: resolvedAlbum,
            duration: mediaItem.playbackDuration,
            genreNames: resolvedGenres,
            playCount: Int(mediaItem.playCount),
            releaseYear: resolvedYear,
            bpm: resolvedBPM,
            mediaPersistentID: UInt64(mediaItem.persistentID),
            albumPersistentID: UInt64(mediaItem.albumPersistentID)
        )
    }
    #endif
}

struct DemoAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let artistName: String
    let songs: [DemoSong]
    let releaseYear: Int
    let genreNames: [String]
    let averageBPM: Double

    init(title: String, artistName: String, songs: [DemoSong]) {
        self.id = "\(title)-\(artistName)".lowercased().replacingOccurrences(of: " ", with: "-")
        self.title = title
        self.artistName = artistName
        self.songs = songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        self.releaseYear = songs.map(\.releaseYear).min() ?? 2024
        self.genreNames = Array(Set(songs.flatMap(\.genreNames))).sorted()
        let totalBPM = songs.reduce(0) { $0 + $1.bpm }
        self.averageBPM = totalBPM / Double(max(songs.count, 1))
    }
}

extension Collection where Element == DemoSong {
    var groupedAsDemoAlbums: [DemoAlbum] {
        Dictionary(grouping: Array(self)) { song in
            if let albumPersistentID = song.albumPersistentID, albumPersistentID > 0 {
                return "album-\(albumPersistentID)"
            }
            return "\(song.albumTitle)|\(song.artistName)"
        }
        .values
        .map { group in
            DemoAlbum(
                title: group.first?.albumTitle ?? "Unknown Album",
                artistName: group.first?.artistName ?? "Unknown Artist",
                songs: group
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

enum DemoSongLibrary {
    static let songs: [DemoSong] = [
        DemoSong("A Day in the Life", artist: "The Beatles", album: "Sgt. Pepper's", duration: 337, genres: ["Rock"], plays: 892, year: 1967),
        DemoSong("Africa", artist: "Toto", album: "Toto IV", duration: 295, genres: ["Rock", "Pop"], plays: 1204, year: 1982),
        DemoSong("All Along the Watchtower", artist: "Jimi Hendrix", album: "Electric Ladyland", duration: 241, genres: ["Rock"], plays: 654, year: 1968),
        DemoSong("Alright", artist: "Kendrick Lamar", album: "To Pimp a Butterfly", duration: 219, genres: ["Hip-Hop"], plays: 445, year: 2015),
        DemoSong("Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 354, genres: ["Rock"], plays: 2103, year: 1975),
        DemoSong("Billie Jean", artist: "Michael Jackson", album: "Thriller", duration: 294, genres: ["Pop", "R&B"], plays: 1876, year: 1982),
        DemoSong("Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200, genres: ["Pop", "Synth-pop"], plays: 3201, year: 2020),
        DemoSong("Born to Run", artist: "Bruce Springsteen", album: "Born to Run", duration: 270, genres: ["Rock"], plays: 567, year: 1975),
        DemoSong("Come Together", artist: "The Beatles", album: "Abbey Road", duration: 259, genres: ["Rock"], plays: 1432, year: 1969),
        DemoSong("Creep", artist: "Radiohead", album: "Pablo Honey", duration: 236, genres: ["Alternative"], plays: 987, year: 1993),
        DemoSong("Crazy in Love", artist: "Beyoncé", album: "Dangerously in Love", duration: 236, genres: ["R&B", "Pop"], plays: 1654, year: 2003),
        DemoSong("Clocks", artist: "Coldplay", album: "A Rush of Blood to the Head", duration: 307, genres: ["Alternative"], plays: 1123, year: 2002),
        DemoSong("Dreams", artist: "Fleetwood Mac", album: "Rumours", duration: 257, genres: ["Rock"], plays: 1876, year: 1977),
        DemoSong("Don't Stop Believin'", artist: "Journey", album: "Escape", duration: 250, genres: ["Rock"], plays: 2345, year: 1981),
        DemoSong("Dancing Queen", artist: "ABBA", album: "Arrival", duration: 231, genres: ["Pop", "Disco"], plays: 1567, year: 1976),
        DemoSong("Enter Sandman", artist: "Metallica", album: "Metallica", duration: 331, genres: ["Metal"], plays: 1234, year: 1991),
        DemoSong("Every Breath You Take", artist: "The Police", album: "Synchronicity", duration: 253, genres: ["Rock", "Pop"], plays: 1890, year: 1983),
        DemoSong("Everything in Its Right Place", artist: "Radiohead", album: "Kid A", duration: 250, genres: ["Electronic", "Alternative"], plays: 456, year: 2000),
        DemoSong("Feel Good Inc.", artist: "Gorillaz", album: "Demon Days", duration: 221, genres: ["Alternative", "Hip-Hop"], plays: 1678, year: 2005),
        DemoSong("Fly Me to the Moon", artist: "Frank Sinatra", album: "It Might as Well Be Swing", duration: 150, genres: ["Jazz"], plays: 789, year: 1964),
        DemoSong("Free Bird", artist: "Lynyrd Skynyrd", album: "Pronounced", duration: 545, genres: ["Rock"], plays: 876, year: 1973),
        DemoSong("Get Lucky", artist: "Daft Punk", album: "Random Access Memories", duration: 369, genres: ["Electronic", "Funk"], plays: 2456, year: 2013),
        DemoSong("Go Your Own Way", artist: "Fleetwood Mac", album: "Rumours", duration: 218, genres: ["Rock"], plays: 1345, year: 1977),
        DemoSong("Good Vibrations", artist: "The Beach Boys", album: "Smiley Smile", duration: 215, genres: ["Pop", "Rock"], plays: 678, year: 1966),
        DemoSong("Hotel California", artist: "Eagles", album: "Hotel California", duration: 391, genres: ["Rock"], plays: 2678, year: 1977),
        DemoSong("Humble", artist: "Kendrick Lamar", album: "DAMN.", duration: 177, genres: ["Hip-Hop"], plays: 1987, year: 2017),
        DemoSong("Heart of Gold", artist: "Neil Young", album: "Harvest", duration: 187, genres: ["Folk", "Rock"], plays: 543, year: 1972),
        DemoSong("Imagine", artist: "John Lennon", album: "Imagine", duration: 187, genres: ["Rock", "Pop"], plays: 1567, year: 1971),
        DemoSong("In the Air Tonight", artist: "Phil Collins", album: "Face Value", duration: 333, genres: ["Pop", "Rock"], plays: 1234, year: 1981),
        DemoSong("Idioteque", artist: "Radiohead", album: "Kid A", duration: 309, genres: ["Electronic"], plays: 345, year: 2000),
        DemoSong("Jolene", artist: "Dolly Parton", album: "Jolene", duration: 162, genres: ["Country"], plays: 1456, year: 1973),
        DemoSong("Just the Two of Us", artist: "Grover Washington Jr.", album: "Winelight", duration: 452, genres: ["Jazz", "R&B"], plays: 876, year: 1981),
        DemoSong("Jump", artist: "Van Halen", album: "1984", duration: 241, genres: ["Rock"], plays: 1123, year: 1984),
        DemoSong("Killing Me Softly", artist: "Fugees", album: "The Score", duration: 296, genres: ["Hip-Hop", "R&B"], plays: 1345, year: 1996),
        DemoSong("Kiss", artist: "Prince", album: "Parade", duration: 226, genres: ["Pop", "Funk"], plays: 987, year: 1986),
        DemoSong("Karma Police", artist: "Radiohead", album: "OK Computer", duration: 264, genres: ["Alternative"], plays: 678, year: 1997),
        DemoSong("Lose Yourself", artist: "Eminem", album: "8 Mile OST", duration: 326, genres: ["Hip-Hop"], plays: 2345, year: 2002),
        DemoSong("Let It Be", artist: "The Beatles", album: "Let It Be", duration: 243, genres: ["Rock", "Pop"], plays: 1987, year: 1970),
        DemoSong("Levitating", artist: "Dua Lipa", album: "Future Nostalgia", duration: 203, genres: ["Pop", "Disco"], plays: 2876, year: 2020),
        DemoSong("Money", artist: "Pink Floyd", album: "The Dark Side of the Moon", duration: 382, genres: ["Rock"], plays: 1234, year: 1973),
        DemoSong("Mr. Brightside", artist: "The Killers", album: "Hot Fuss", duration: 222, genres: ["Alternative", "Rock"], plays: 3456, year: 2004),
        DemoSong("My Girl", artist: "The Temptations", album: "The Temptations Sing Smokey", duration: 177, genres: ["R&B", "Soul"], plays: 1123, year: 1965),
        DemoSong("Maps", artist: "Yeah Yeah Yeahs", album: "Fever to Tell", duration: 217, genres: ["Indie Rock"], plays: 567, year: 2003),
        DemoSong("No Woman, No Cry", artist: "Bob Marley", album: "Live!", duration: 467, genres: ["Reggae"], plays: 1567, year: 1975),
        DemoSong("Night Changes", artist: "One Direction", album: "FOUR", duration: 226, genres: ["Pop"], plays: 1890, year: 2014),
        DemoSong("Nuthin' but a 'G' Thang", artist: "Dr. Dre", album: "The Chronic", duration: 238, genres: ["Hip-Hop"], plays: 987, year: 1992),
        DemoSong("One", artist: "U2", album: "Achtung Baby", duration: 276, genres: ["Rock"], plays: 1234, year: 1991),
        DemoSong("Overture", artist: "The Who", album: "Tommy", duration: 336, genres: ["Rock"], plays: 345, year: 1969),
        DemoSong("Outcast", artist: "NF", album: "The Search", duration: 213, genres: ["Hip-Hop"], plays: 876, year: 2019),
        DemoSong("Paint It Black", artist: "The Rolling Stones", album: "Aftermath", duration: 222, genres: ["Rock"], plays: 1567, year: 1966),
        DemoSong("Purple Rain", artist: "Prince", album: "Purple Rain", duration: 521, genres: ["Rock", "Pop"], plays: 1345, year: 1984),
        DemoSong("Paranoid Android", artist: "Radiohead", album: "OK Computer", duration: 383, genres: ["Alternative"], plays: 567, year: 1997),
        DemoSong("Queen of the Night", artist: "Whitney Houston", album: "The Bodyguard OST", duration: 196, genres: ["Pop", "R&B"], plays: 876, year: 1992),
        DemoSong("Quit Playing Games", artist: "Backstreet Boys", album: "Backstreet Boys", duration: 234, genres: ["Pop"], plays: 654, year: 1997),
        DemoSong("Respect", artist: "Aretha Franklin", album: "I Never Loved a Man", duration: 147, genres: ["R&B", "Soul"], plays: 1678, year: 1967),
        DemoSong("Rocketman", artist: "Elton John", album: "Honky Château", duration: 281, genres: ["Rock", "Pop"], plays: 1234, year: 1972),
        DemoSong("Redbone", artist: "Childish Gambino", album: "Awaken, My Love!", duration: 327, genres: ["R&B", "Funk"], plays: 1987, year: 2016),
        DemoSong("Smells Like Teen Spirit", artist: "Nirvana", album: "Nevermind", duration: 301, genres: ["Grunge", "Rock"], plays: 2678, year: 1991),
        DemoSong("Superstition", artist: "Stevie Wonder", album: "Talking Book", duration: 285, genres: ["Funk", "R&B"], plays: 1456, year: 1972),
        DemoSong("Starboy", artist: "The Weeknd", album: "Starboy", duration: 230, genres: ["Pop", "R&B"], plays: 2345, year: 2016),
        DemoSong("Sweet Child O' Mine", artist: "Guns N' Roses", album: "Appetite for Destruction", duration: 356, genres: ["Rock"], plays: 1890, year: 1987),
        DemoSong("Take On Me", artist: "a-ha", album: "Hunting High and Low", duration: 225, genres: ["Pop", "Synth-pop"], plays: 1678, year: 1985),
        DemoSong("Thriller", artist: "Michael Jackson", album: "Thriller", duration: 357, genres: ["Pop"], plays: 2123, year: 1982),
        DemoSong("Time", artist: "Pink Floyd", album: "The Dark Side of the Moon", duration: 413, genres: ["Rock"], plays: 987, year: 1973),
        DemoSong("Toxic", artist: "Britney Spears", album: "In the Zone", duration: 198, genres: ["Pop"], plays: 1567, year: 2004),
        DemoSong("Under Pressure", artist: "Queen & David Bowie", album: "Hot Space", duration: 248, genres: ["Rock"], plays: 1890, year: 1981),
        DemoSong("Umbrella", artist: "Rihanna", album: "Good Girl Gone Bad", duration: 276, genres: ["Pop", "R&B"], plays: 2345, year: 2007),
        DemoSong("Viva la Vida", artist: "Coldplay", album: "Viva la Vida", duration: 242, genres: ["Alternative", "Rock"], plays: 2678, year: 2008),
        DemoSong("Video Killed the Radio Star", artist: "The Buggles", album: "The Age of Plastic", duration: 252, genres: ["Pop", "New Wave"], plays: 876, year: 1979),
        DemoSong("Wonderwall", artist: "Oasis", album: "(What's the Story) Morning Glory?", duration: 258, genres: ["Rock"], plays: 3123, year: 1995),
        DemoSong("Watermelon Sugar", artist: "Harry Styles", album: "Fine Line", duration: 174, genres: ["Pop"], plays: 2456, year: 2019),
        DemoSong("When Doves Cry", artist: "Prince", album: "Purple Rain", duration: 352, genres: ["Pop", "Funk"], plays: 1234, year: 1984),
        DemoSong("XO", artist: "Beyoncé", album: "Beyoncé", duration: 196, genres: ["Pop", "R&B"], plays: 1123, year: 2013),
        DemoSong("X Gon' Give It to Ya", artist: "DMX", album: "Cradle 2 the Grave OST", duration: 215, genres: ["Hip-Hop"], plays: 987, year: 2003),
        DemoSong("Yesterday", artist: "The Beatles", album: "Help!", duration: 125, genres: ["Pop", "Rock"], plays: 1876, year: 1965),
        DemoSong("You Shook Me All Night Long", artist: "AC/DC", album: "Back in Black", duration: 210, genres: ["Rock"], plays: 1567, year: 1980),
        DemoSong("Yellow", artist: "Coldplay", album: "Parachutes", duration: 269, genres: ["Alternative"], plays: 1345, year: 2000),
        DemoSong("Zombie", artist: "The Cranberries", album: "No Need to Argue", duration: 306, genres: ["Alternative", "Rock"], plays: 1678, year: 1994),
        DemoSong("Ziggy Stardust", artist: "David Bowie", album: "Ziggy Stardust", duration: 194, genres: ["Rock"], plays: 876, year: 1972),
        DemoSong("1999", artist: "Prince", album: "1999", duration: 377, genres: ["Pop", "Funk"], plays: 1234, year: 1982),
        DemoSong("99 Problems", artist: "Jay-Z", album: "The Black Album", duration: 224, genres: ["Hip-Hop"], plays: 1567, year: 2003),
        DemoSong("7 Rings", artist: "Ariana Grande", album: "Thank U, Next", duration: 179, genres: ["Pop", "R&B"], plays: 2876, year: 2019),
    ]

    static let albums: [DemoAlbum] = {
        songs.groupedAsDemoAlbums
    }()
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
