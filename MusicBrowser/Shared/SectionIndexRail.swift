import SwiftUI

/// Apple Music-style drag-to-scrub section index rail.
///
/// Replaces the old tap-per-letter approach with a continuous `DragGesture`
/// mapped through `GeometryReader`. As the user's finger moves vertically,
/// the Y position is converted to a letter index (`availableHeight / letterCount`),
/// firing haptic feedback on each transition and scrolling the parent list
/// via `onScrollTo`. A floating bubble appears 62 pt to the left during drag,
/// showing the current letter at large size — mirroring the native Contacts /
/// Apple Music scrub UX.
struct SectionIndexRail: View {

    // MARK: - Public interface (unchanged from previous version)

    let availableLetters: Set<String>
    let onScrollTo: (String) -> Void

    // MARK: - Private state

    /// All 27 index letters: A-Z plus # for non-alpha titles.
    private let letters = AlphabetJumpRail.preGeneratedLetters
    /// Rail width — wide enough for reliable touch targeting.
    private let railWidth: CGFloat = 28

    /// Tracks whether the user's finger is currently on the rail.
    /// Resets to `false` automatically when the gesture ends, which
    /// drives the bubble & highlight cleanup animations.
    @GestureState private var isDragging: Bool = false

    /// The letter the user is currently hovering over (or last hovered).
    /// Updated during drag; cleared on gesture end after a short delay
    /// so the exit animation can play.
    @State private var activeLetter: String?

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let letterHeight = geo.size.height / CGFloat(letters.count)

            ZStack(alignment: .trailing) {

                // ── Floating bubble ───────────────────────────────
                // Appears to the left of the rail while dragging.
                if isDragging, let active = activeLetter {
                    bubbleView(for: active)
                        .position(
                            x: -62 + (railWidth / 2),
                            y: yPosition(for: active, letterHeight: letterHeight)
                        )
                        .transition(.opacity)
                }

                // ── Letter column ─────────────────────────────────
                VStack(spacing: 0) {
                    ForEach(Array(letters.enumerated()), id: \.element) { _, letter in
                        letterLabel(letter, height: letterHeight)
                    }
                }
                .frame(width: railWidth, height: geo.size.height)
                .contentShape(Rectangle())
                .highPriorityGesture(dragGesture(geo: geo, letterHeight: letterHeight), including: .all)
            }
            .frame(width: railWidth, height: geo.size.height, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .frame(width: railWidth)
        // When the finger lifts, clean up the active letter after the
        // exit animation completes so the highlight doesn't linger.
        .onChange(of: isDragging) { _, newValue in
            if !newValue {
                withAnimation(.easeOut(duration: 0.2)) {
                    activeLetter = nil
                }
            }
        }
    }

    // MARK: - Sub-views

    /// Individual letter label inside the rail column.
    /// Scales up when active and shifts color to accent.
    @ViewBuilder
    private func letterLabel(_ letter: String, height: CGFloat) -> some View {
        let isActive = activeLetter == letter && isDragging
        let isAvailable = availableLetters.contains(letter)

        Text(letter)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(
                isActive
                    ? Color.accentColor
                    : Color(.label).opacity(isAvailable ? 0.78 : 0.2)
            )
            .scaleEffect(isActive ? 1.3 : 1.0)
            .frame(width: railWidth, height: height)
            .animation(.snappy(duration: 0.15), value: activeLetter)
    }

    /// 52x52 floating bubble that displays the active letter in large text.
    /// Uses `.thinMaterial` for a frosted glass look that adapts to light/dark.
    @ViewBuilder
    private func bubbleView(for letter: String) -> some View {
        Text(letter)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(Color(.label))
            .frame(width: 52, height: 52)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Gesture

    /// Continuous drag gesture that maps Y → letter index.
    /// Uses `@GestureState isDragging` so the flag auto-resets on lift.
    private func dragGesture(geo: GeometryProxy, letterHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                let index = clampedIndex(for: value.location.y, letterHeight: letterHeight)
                let letter = letters[index]

                guard letter != activeLetter else { return }

                // Only scroll to letters that actually have content.
                let isAvailable = availableLetters.contains(letter)

                withAnimation(.snappy(duration: 0.15)) {
                    activeLetter = letter
                }

                if isAvailable {
                    Haptic.selection()
                    onScrollTo(letter)
                }
            }
    }

    // MARK: - Helpers

    /// Clamps a Y position to a valid letter index (0 ..< letters.count).
    private func clampedIndex(for y: CGFloat, letterHeight: CGFloat) -> Int {
        let raw = Int(y / letterHeight)
        return max(0, min(raw, letters.count - 1))
    }

    /// Returns the vertical center Y for a given letter within the rail.
    private func yPosition(for letter: String, letterHeight: CGFloat) -> CGFloat {
        guard let idx = letters.firstIndex(of: letter) else { return 0 }
        return (CGFloat(idx) + 0.5) * letterHeight
    }
}
