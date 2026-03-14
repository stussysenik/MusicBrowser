import Foundation
import MusicKit

@Observable
final class LyricsService {
    var currentLyrics: [LyricLine]?
    var isLoading = false
    var loadError: Error?

    private var cache: [MusicItemID: [LyricLine]] = [:]

    struct LyricLine: Identifiable {
        let id = UUID()
        let text: String
        let startTime: TimeInterval?
        let endTime: TimeInterval?
    }

    func fetchLyrics(for songID: MusicItemID) async {
        if let cached = cache[songID] {
            currentLyrics = cached
            return
        }

        isLoading = true
        loadError = nil

        do {
            let countryCode = try await MusicDataRequest.currentCountryCode
            let url = URL(string: "https://api.music.apple.com/v1/catalog/\(countryCode)/songs/\(songID.rawValue)/lyrics")!
            let request = MusicDataRequest(urlRequest: URLRequest(url: url))
            let response = try await request.response()

            let lines = TTMLParser.parse(data: response.data)
            cache[songID] = lines
            currentLyrics = lines
            isLoading = false
        } catch {
            loadError = error
            currentLyrics = nil
            isLoading = false
        }
    }

    func clear() {
        currentLyrics = nil
        loadError = nil
        isLoading = false
    }
}

// MARK: - TTML Parser

private enum TTMLParser {
    static func parse(data: Data) -> [LyricsService.LyricLine] {
        let parser = TTMLXMLDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        xmlParser.parse()
        return parser.lines
    }
}

private final class TTMLXMLDelegate: NSObject, XMLParserDelegate {
    var lines: [LyricsService.LyricLine] = []
    private var currentText = ""
    private var currentBegin: TimeInterval?
    private var currentEnd: TimeInterval?
    private var inP = false
    private var inSpan = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if elementName == "p" || elementName == "span" {
            if elementName == "p" { inP = true }
            if elementName == "span" { inSpan = true }
            currentText = ""
            currentBegin = parseTime(attributes["begin"])
            currentEnd = parseTime(attributes["end"])
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inP || inSpan {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "p" {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                lines.append(.init(text: trimmed, startTime: currentBegin, endTime: currentEnd))
            }
            inP = false
            currentText = ""
        }
        if elementName == "span" {
            inSpan = false
        }
    }

    private func parseTime(_ value: String?) -> TimeInterval? {
        guard let value else { return nil }

        // Handle HH:MM:SS.mmm or MM:SS.mmm formats
        let components = value.split(separator: ":")
        guard components.count >= 2 else { return nil }

        if components.count == 3 {
            guard let h = Double(components[0]),
                  let m = Double(components[1]),
                  let s = Double(components[2]) else { return nil }
            return h * 3600 + m * 60 + s
        } else {
            guard let m = Double(components[0]),
                  let s = Double(components[1]) else { return nil }
            return m * 60 + s
        }
    }
}
