import SwiftUI

/// iOS Contacts-style alphabetical index rail with drag scrubbing,
/// magnified letter bubble, and double-tap pinning support.
///
/// Touch target is 44pt wide (HIG minimum), visual rail is 28pt with
/// a permanent frosted capsule backdrop so letters stay visible on any
/// background. Font is 11pt semibold for available, bold+accent for pinned,
/// and 0.25 opacity for unavailable.
struct SectionIndexRail: View {
    let availableLetters: Set<String>
    let pinnedLetters: Set<String>
    let onScrollTo: (String) -> Void
    let onDoubleTap: (String) -> Void

    init(
        availableLetters: Set<String>,
        pinnedLetters: Set<String> = [],
        onScrollTo: @escaping (String) -> Void,
        onDoubleTap: @escaping (String) -> Void = { _ in }
    ) {
        self.availableLetters = availableLetters
        self.pinnedLetters = pinnedLetters
        self.onScrollTo = onScrollTo
        self.onDoubleTap = onDoubleTap
    }

    private static let letters = AlphabetJumpRail.preGeneratedLetters

    // O(1) letter→index lookup (pre-computed once)
    private static let letterIndexMap: [String: Int] = {
        var map: [String: Int] = [:]
        for (i, letter) in letters.enumerated() {
            map[letter] = i
        }
        return map
    }()

    @State private var isScrubbing = false
    @State private var currentScrubbingLetter: String?

    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let letterHeight = max(totalHeight / CGFloat(Self.letters.count), 16)

            ZStack(alignment: .trailing) {
                // Letter column — always has a frosted backdrop
                LetterColumn(
                    letters: Self.letters,
                    availableLetters: availableLetters,
                    pinnedLetters: pinnedLetters,
                    currentScrubbingLetter: currentScrubbingLetter,
                    isScrubbing: isScrubbing,
                    letterHeight: letterHeight,
                    onScrollTo: onScrollTo,
                    onDoubleTap: onDoubleTap
                )

                // Magnified bubble overlay
                if isScrubbing, let current = currentScrubbingLetter {
                    magnifiedBubble(letter: current, totalHeight: totalHeight, letterHeight: letterHeight)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 28, alignment: .center)
            .contentShape(Rectangle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = Int(value.location.y / letterHeight)
                        guard index >= 0, index < Self.letters.count else { return }
                        let letter = Self.letters[index]
                        guard availableLetters.contains(letter) else { return }

                        if !isScrubbing {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isScrubbing = true
                            }
                        }

                        if letter != currentScrubbingLetter {
                            currentScrubbingLetter = letter
                            Haptic.selection()
                            onScrollTo(letter)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            isScrubbing = false
                        }
                        currentScrubbingLetter = nil
                    }
            )
        }
        .padding(.vertical, 4)
        .frame(width: 44) // 44pt touch target (HIG)
    }

    // MARK: - Magnified Bubble

    @ViewBuilder
    private func magnifiedBubble(letter: String, totalHeight: CGFloat, letterHeight: CGFloat) -> some View {
        let index = Self.letterIndexMap[letter] ?? 0
        let yOffset = CGFloat(index) * letterHeight + letterHeight / 2 - 30

        Text(letter)
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            )
            .offset(x: -60, y: yOffset)
            .allowsHitTesting(false)
    }
}

// MARK: - Letter Column (extracted to avoid full VStack re-render during scrub)

private struct LetterColumn: View {
    let letters: [String]
    let availableLetters: Set<String>
    let pinnedLetters: Set<String>
    let currentScrubbingLetter: String?
    let isScrubbing: Bool
    let letterHeight: CGFloat
    let onScrollTo: (String) -> Void
    let onDoubleTap: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                letterView(letter)
            }
        }
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(isScrubbing ? 1.0 : 0.6)
                .animation(.easeOut(duration: 0.15), value: isScrubbing)
        }
    }

    @ViewBuilder
    private func letterView(_ letter: String) -> some View {
        let isAvailable = availableLetters.contains(letter)
        let isPinned = pinnedLetters.contains(letter)
        let isCurrentScrub = currentScrubbingLetter == letter

        Text(letter)
            .font(.system(size: 11, weight: isPinned ? .bold : .semibold))
            .foregroundStyle(
                isPinned ? Color.accentColor :
                isAvailable ? Color(.label) : Color(.label).opacity(0.25)
            )
            .frame(width: 28, height: letterHeight)
            .background {
                if isCurrentScrub && isScrubbing {
                    Circle()
                        .fill(Color.accentColor.opacity(0.25))
                        .frame(width: 24, height: 24)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard isAvailable else { return }
                Haptic.medium()
                onDoubleTap(letter)
            }
            .onTapGesture(count: 1) {
                guard isAvailable else { return }
                Haptic.selection()
                onScrollTo(letter)
            }
    }
}
