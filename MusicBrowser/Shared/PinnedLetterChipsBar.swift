import SwiftUI

/// Horizontal strip of pinned-letter chips with dismiss buttons and "Clear All" trailing action.
struct PinnedLetterChipsBar: View {
    let pinnedLetters: Set<String>
    let onUnpin: (String) -> Void
    let onClearAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pinnedLetters.sorted(), id: \.self) { letter in
                    chipView(letter)
                }

                Button(action: onClearAll) {
                    Text("Clear All")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.bar)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func chipView(_ letter: String) -> some View {
        HStack(spacing: 4) {
            Text(letter)
                .font(.subheadline.bold())

            Button {
                onUnpin(letter)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 0.5)
        )
    }
}
