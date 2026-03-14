import MusicKit

extension Song: FilterableByLetter {}

extension Album: FilterableByLetter {}

extension Artist: FilterableByLetter {
    var title: String { name }
}

extension Playlist: FilterableByLetter {
    var title: String { name }
}
