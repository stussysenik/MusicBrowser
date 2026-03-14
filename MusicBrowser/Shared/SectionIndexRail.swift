import SwiftUI

struct SectionIndexRail: View {
    let availableLetters: Set<String>
    let onScrollTo: (String) -> Void

    private let letters = AlphabetJumpRail.preGeneratedLetters

    var body: some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                let isAvailable = availableLetters.contains(letter)
                Button {
                    guard isAvailable else { return }
                    Haptic.selection()
                    onScrollTo(letter)
                } label: {
                    Text(letter)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(.label).opacity(isAvailable ? 0.78 : 0.2))
                        .frame(width: 20, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isAvailable)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 20)
    }
}
