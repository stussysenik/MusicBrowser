import SwiftUI
import SwiftData
import MusicKit

struct NotesListView: View {
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext

    @State private var annotations: [SongAnnotation] = []
    @State private var showExport = false

    var body: some View {
        Group {
            if annotations.isEmpty {
                ContentUnavailableView("No Notes", systemImage: "note.text", description: Text("Annotations you add to songs will appear here."))
            } else {
                List(annotations, id: \.songID) { annotation in
                    annotationRow(annotation)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("All Notes")
        .toolbar {
            if !annotations.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showExport) {
            ExportSheet()
        }
        .onAppear {
            annotations = annotationService.allAnnotations(in: modelContext)
        }
    }

    private func annotationRow(_ annotation: SongAnnotation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(annotation.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if annotation.rating > 0 {
                    Text(String(repeating: "★", count: annotation.rating))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(annotation.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !annotation.notes.isEmpty {
                Text(annotation.notes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Text(annotation.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Notes List") {
    PreviewHost {
        NavigationStack {
            NotesListView()
        }
    }
}
