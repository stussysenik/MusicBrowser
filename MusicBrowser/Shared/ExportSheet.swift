import SwiftUI
import SwiftData

/// Multi-format export sheet for annotations.
struct ExportSheet: View {
    @Environment(AnnotationService.self) private var annotationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exportedText: String?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("Export Format") {
                    Button {
                        if let data = try? annotationService.exportJSON(in: modelContext),
                           let text = String(data: data, encoding: .utf8) {
                            exportedText = text
                            showShareSheet = true
                        }
                    } label: {
                        Label("JSON", systemImage: "doc.text")
                    }

                    Button {
                        exportedText = annotationService.exportMarkdown(in: modelContext)
                        showShareSheet = true
                    } label: {
                        Label("Markdown", systemImage: "doc.richtext")
                    }

                    Button {
                        exportedText = annotationService.exportCSV(in: modelContext)
                        showShareSheet = true
                    } label: {
                        Label("CSV", systemImage: "tablecells")
                    }
                }

                Section("Quick Actions") {
                    Button {
                        let md = annotationService.exportMarkdown(in: modelContext)
                        annotationService.copyToClipboard(md)
                        Haptic.success()
                        dismiss()
                    } label: {
                        Label("Copy Markdown to Clipboard", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        let csv = annotationService.exportCSV(in: modelContext)
                        annotationService.copyToClipboard(csv)
                        Haptic.success()
                        dismiss()
                    } label: {
                        Label("Copy CSV to Clipboard", systemImage: "doc.on.clipboard")
                    }
                }
            }
            .navigationTitle("Export Annotations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                if let text = exportedText {
                    ShareSheet(items: [text])
                }
            }
            #endif
        }
    }
}

#if os(iOS)
/// Wraps UIActivityViewController for sharing.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
