import Foundation

/// Generates curated and procedural mock data for wireframe testing.
enum MockDataGenerator {

    // MARK: - Curated Songs (50 hand-crafted entries)

    static func curatedSongs() -> [MockSong] {
        let entries: [(String, String, String, [String], Double?, Int?)] = [
            ("Bohemian Rhapsody", "Queen", "A Night at the Opera", ["Rock"], 72, 1975),
            ("Billie Jean", "Michael Jackson", "Thriller", ["Pop"], 117, 1982),
            ("Smells Like Teen Spirit", "Nirvana", "Nevermind", ["Grunge", "Rock"], 117, 1991),
            ("Imagine", "John Lennon", "Imagine", ["Pop", "Rock"], 75, 1971),
            ("Hotel California", "Eagles", "Hotel California", ["Rock"], 74, 1977),
            ("Superstition", "Stevie Wonder", "Talking Book", ["Funk", "R&B"], 101, 1972),
            ("Blinding Lights", "The Weeknd", "After Hours", ["Synth-Pop"], 171, 2020),
            ("Lose Yourself", "Eminem", "8 Mile OST", ["Hip-Hop"], 171, 2002),
            ("Rolling in the Deep", "Adele", "21", ["Pop", "Soul"], 105, 2011),
            ("Stairway to Heaven", "Led Zeppelin", "Led Zeppelin IV", ["Rock"], 63, 1971),
            ("Purple Rain", "Prince", "Purple Rain", ["Pop", "Rock"], 113, 1984),
            ("One", "Metallica", "...And Justice for All", ["Metal"], 138, 1988),
            ("Watermelon Sugar", "Harry Styles", "Fine Line", ["Pop"], 95, 2019),
            ("Get Lucky", "Daft Punk", "Random Access Memories", ["Disco", "Electronic"], 116, 2013),
            ("Take Five", "Dave Brubeck", "Time Out", ["Jazz"], 174, 1959),
            ("A Love Supreme Pt. 1", "John Coltrane", "A Love Supreme", ["Jazz"], 92, 1965),
            ("Redbone", "Childish Gambino", "Awaken My Love!", ["Funk", "R&B"], 81, 2016),
            ("Nights", "Frank Ocean", "Blonde", ["R&B", "Pop"], 82, 2016),
            ("Electric Feel", "MGMT", "Oracular Spectacular", ["Indie", "Electronic"], 120, 2007),
            ("Everything In Its Right Place", "Radiohead", "Kid A", ["Electronic", "Rock"], 126, 2000),
            ("Midnight City", "M83", "Hurry Up We're Dreaming", ["Electronic"], 105, 2011),
            ("All Too Well (10 Min)", "Taylor Swift", "Red (TV)", ["Pop", "Country"], 95, 2021),
            ("Formation", "Beyoncé", "Lemonade", ["Pop", "Hip-Hop"], 124, 2016),
            ("Alright", "Kendrick Lamar", "To Pimp a Butterfly", ["Hip-Hop", "Jazz"], 114, 2015),
            ("Dreams", "Fleetwood Mac", "Rumours", ["Rock", "Pop"], 120, 1977),
            ("Blue Monday", "New Order", "Power Corruption & Lies", ["Electronic"], 130, 1983),
            ("Karma Police", "Radiohead", "OK Computer", ["Rock"], 73, 1997),
            ("Runaway", "Kanye West", "My Beautiful Dark Twisted Fantasy", ["Hip-Hop"], 85, 2010),
            ("Bad Guy", "Billie Eilish", "When We All Fall Asleep", ["Pop", "Electronic"], 135, 2019),
            ("Dance Yrself Clean", "LCD Soundsystem", "This Is Happening", ["Electronic"], 138, 2010),
            ("Clair de Lune", "Claude Debussy", "Suite Bergamasque", ["Classical"], 66, 1905),
            ("So What", "Miles Davis", "Kind of Blue", ["Jazz"], 136, 1959),
            ("Teardrop", "Massive Attack", "Mezzanine", ["Trip-Hop", "Electronic"], 80, 1998),
            ("Under Pressure", "Queen & David Bowie", "Hot Space", ["Rock", "Pop"], 148, 1981),
            ("No Diggity", "Blackstreet", "Another Level", ["R&B", "Hip-Hop"], 93, 1996),
            ("Paranoid Android", "Radiohead", "OK Computer", ["Rock"], 82, 1997),
            ("Africa", "Toto", "Toto IV", ["Pop", "Rock"], 92, 1982),
            ("Stronger", "Kanye West", "Graduation", ["Hip-Hop", "Electronic"], 104, 2007),
            ("XO", "Beyoncé", "Beyoncé", ["Pop", "R&B"], 120, 2013),
            ("Feel Good Inc.", "Gorillaz", "Demon Days", ["Hip-Hop", "Electronic"], 139, 2005),
            ("Mr. Brightside", "The Killers", "Hot Fuss", ["Rock"], 148, 2003),
            ("Jolene", "Dolly Parton", "Jolene", ["Country"], 112, 1973),
            ("Doo Wop (That Thing)", "Lauryn Hill", "Miseducation", ["Hip-Hop", "R&B"], 100, 1998),
            ("Genesis", "Grimes", "Visions", ["Electronic"], 130, 2012),
            ("Naive Melody", "Talking Heads", "Speaking in Tongues", ["New Wave"], 101, 1983),
            ("Nikes", "Frank Ocean", "Blonde", ["R&B", "Electronic"], 87, 2016),
            ("Vapour Trail", "Ride", "Nowhere", ["Shoegaze"], 95, 1990),
            ("You Make My Dreams", "Hall & Oates", "Voices", ["Pop"], 148, 1980),
            ("Zombie", "Fela Kuti", "Zombie", ["Afrobeat"], 95, 1977),
            ("Digital Love", "Daft Punk", "Discovery", ["Electronic", "Disco"], 125, 2001),
        ]

        return entries.enumerated().map { idx, e in
            let cal = Calendar.current
            let date = e.5.map { cal.date(from: DateComponents(year: $0, month: 6, day: 15)) ?? Date() }
            return MockSong(
                id: "mock-song-\(idx)",
                title: e.0,
                artistName: e.1,
                albumTitle: e.2,
                duration: TimeInterval.random(in: 150...420),
                genreNames: e.3,
                playCount: Int.random(in: 1...500),
                releaseDate: date,
                releaseYear: e.5,
                bpm: e.4
            )
        }
    }

    // MARK: - Stress Test Songs (procedurally generated)

    static func stressTestSongs(count: Int = 1000) -> [MockSong] {
        let firstNames = ["Midnight", "Golden", "Electric", "Broken", "Crystal", "Silver", "Velvet",
                          "Neon", "Shadow", "Cosmic", "Burning", "Frozen", "Silent", "Thunder", "Ocean"]
        let secondNames = ["Dreams", "Highway", "Symphony", "Echoes", "Heartbeat", "Memory", "River",
                           "Storm", "Light", "Fire", "Dance", "Rain", "Wind", "Sky", "Wave"]
        let artists = ["Luna Park", "The Resonators", "Jade Compass", "Polar Echo", "Skyline",
                       "Nocturn", "Drift Theory", "Phase Shift", "Glass Animals", "Ruby Fleet",
                       "Cosmo Drive", "Soft Machine", "The Alchemists", "Iron Veil", "Pastel Ghost"]
        let genres = ["Pop", "Rock", "Electronic", "Hip-Hop", "R&B", "Jazz", "Country",
                      "Metal", "Classical", "Indie", "Folk", "Funk", "Soul", "Reggae", "Latin"]

        return (0..<count).map { idx in
            MockSong(
                id: "mock-stress-\(idx)",
                title: "\(firstNames.randomElement()!) \(secondNames.randomElement()!)",
                artistName: artists.randomElement()!,
                albumTitle: "Album \(idx / 12 + 1)",
                duration: TimeInterval.random(in: 120...600),
                genreNames: [genres.randomElement()!, genres.randomElement()!].uniqued(),
                playCount: Int.random(in: 0...1000),
                releaseDate: nil,
                releaseYear: Int.random(in: 1960...2026),
                bpm: Double.random(in: 60...200)
            )
        }
    }

    // MARK: - Derived Collections

    static func deriveAlbums(from songs: [MockSong]) -> [MockAlbum] {
        Dictionary(grouping: songs) { $0.albumTitle }
            .map { title, albumSongs in
                MockAlbum(
                    title: title,
                    artistName: albumSongs.first?.artistName ?? "Unknown",
                    trackCount: albumSongs.count,
                    releaseYear: albumSongs.first?.releaseYear,
                    genreNames: Array(Set(albumSongs.flatMap(\.genreNames)))
                )
            }
            .sorted { $0.title < $1.title }
    }

    static func deriveArtists(from songs: [MockSong]) -> [MockArtist] {
        Dictionary(grouping: songs) { $0.artistName }
            .map { name, artistSongs in
                MockArtist(name: name, songCount: artistSongs.count)
            }
            .sorted { $0.name < $1.name }
    }

    static func derivePlaylists(from songs: [MockSong]) -> [MockPlaylist] {
        let names = ["Chill Vibes", "Workout Energy", "Late Night Jazz", "Road Trip Mix",
                     "90s Nostalgia", "Focus Flow", "Party Starters", "Acoustic Morning",
                     "Indie Discovery", "Hip-Hop Classics", "Electronic Dreams", "Rock Anthems"]
        return names.enumerated().map { idx, name in
            MockPlaylist(
                id: "mock-playlist-\(idx)",
                name: name,
                curatorName: idx % 3 == 0 ? "MusicBrowser" : nil,
                trackCount: Int.random(in: 10...50)
            )
        }
    }
}

// MARK: - Helpers

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
