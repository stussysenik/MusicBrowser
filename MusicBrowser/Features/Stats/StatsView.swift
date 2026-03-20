import SwiftUI

/// Root stats tab with segmented picker for Listening / Library / Discover / DJ Tools.
/// Uses ZStack + opacity pattern matching LibraryView for tab preservation.
struct StatsView: View {
    @State private var selection: StatsSection = .listening

    enum StatsSection: String, CaseIterable {
        case listening = "Listening"
        case library = "Library"
        case discover = "Discover"
        case djTools = "DJ Tools"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selection) {
                ForEach(StatsSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            ZStack {
                ListeningBehaviorView()
                    .opacity(selection == .listening ? 1 : 0)
                    .allowsHitTesting(selection == .listening)

                LibraryIntelligenceView()
                    .opacity(selection == .library ? 1 : 0)
                    .allowsHitTesting(selection == .library)

                DiscoveryEngineView()
                    .opacity(selection == .discover ? 1 : 0)
                    .allowsHitTesting(selection == .discover)

                DJToolsView()
                    .opacity(selection == .djTools ? 1 : 0)
                    .allowsHitTesting(selection == .djTools)
            }
        }
        .navigationTitle("Stats")
    }
}

#Preview("Stats") {
    PreviewHost {
        NavigationStack {
            StatsView()
        }
    }
}
