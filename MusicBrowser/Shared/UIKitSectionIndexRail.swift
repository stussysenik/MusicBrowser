#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - SwiftUI Bridge

/// A UIKit-backed section index rail that replaces the SwiftUI `DragGesture`
/// implementation. UIKit's `touchesBegan`/`touchesMoved` touch handling is
/// deterministic — it won't conflict with the parent `ScrollView` the way
/// `DragGesture` does, because we set `isExclusiveTouch = true` on the
/// control and handle all phases ourselves.
///
/// ## Architecture
/// `UIKitSectionIndexRail` (a `UIViewRepresentable`) wraps `SectionIndexControl`
/// (a `UIControl` subclass). The control owns 27 `UILabel` children (A-Z + #)
/// arranged in a vertical stack, plus a floating `UIVisualEffectView` bubble
/// that appears 62 pt to the left during touch. On each letter transition a
/// `UISelectionFeedbackGenerator` fires for tactile feedback.
struct UIKitSectionIndexRail: UIViewRepresentable {

    /// Letters that have actual content in the list. Unavailable letters render
    /// dimmed and don't trigger `onScrollTo`.
    let availableLetters: Set<String>
    let canSelectUnavailableLetters: Bool

    /// Called when the user's finger moves over a letter that is available.
    let onScrollTo: (String) -> Void

    init(
        availableLetters: Set<String>,
        canSelectUnavailableLetters: Bool = false,
        onScrollTo: @escaping (String) -> Void
    ) {
        self.availableLetters = availableLetters
        self.canSelectUnavailableLetters = canSelectUnavailableLetters
        self.onScrollTo = onScrollTo
    }

    // MARK: UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollTo: onScrollTo)
    }

    func makeUIView(context: Context) -> SectionIndexControl {
        let control = SectionIndexControl()
        control.coordinator = context.coordinator
        control.updateAvailable(availableLetters)
        control.updateSelectionBehavior(canSelectUnavailableLetters)
        return control
    }

    func updateUIView(_ uiView: SectionIndexControl, context: Context) {
        // Keep the coordinator closure in sync (captures may change).
        context.coordinator.onScrollTo = onScrollTo
        uiView.updateAvailable(availableLetters)
        uiView.updateSelectionBehavior(canSelectUnavailableLetters)
    }

    // MARK: Coordinator

    /// Thin bridge that forwards letter selections from UIKit back to SwiftUI.
    class Coordinator {
        var onScrollTo: (String) -> Void

        init(onScrollTo: @escaping (String) -> Void) {
            self.onScrollTo = onScrollTo
        }
    }
}

// MARK: - UIControl Subclass

/// Custom `UIControl` that renders a vertical list of section letters and
/// responds to touch with immediate, conflict-free recognition.
///
/// ### Why UIControl instead of UIGestureRecognizer?
/// Overriding `touchesBegan`/`touchesMoved` on the control itself means
/// the responder chain never forwards these touches to the scroll view.
/// Combined with `isExclusiveTouch = true`, this eliminates the gesture
/// conflict that plagued the SwiftUI `DragGesture` approach.
class SectionIndexControl: UIControl {

    // MARK: Configuration

    /// The full alphabet plus "#" for non-alpha titles (27 entries).
    private let letters: [String] = AlphabetJumpRail.preGeneratedLetters

    /// Fixed rail width matching the SwiftUI implementation.
    private let railWidth: CGFloat = 28

    /// Horizontal offset of the floating bubble from the rail center.
    private let bubbleOffset: CGFloat = 62

    // MARK: State

    weak var coordinator: UIKitSectionIndexRail.Coordinator?
    private var availableLetters: Set<String> = []
    private var canSelectUnavailableLetters = false
    private var activeLetter: String?

    // MARK: Subviews

    /// One label per letter, laid out evenly in `layoutSubviews`.
    private var letterLabels: [UILabel] = []

    /// Frosted-glass bubble shown during touch.
    private let bubbleEffect: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterial)
        let v = UIVisualEffectView(effect: blur)
        v.frame = CGRect(x: 0, y: 0, width: 52, height: 52)
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.isUserInteractionEnabled = false
        v.alpha = 0
        return v
    }()

    /// Large letter displayed inside the bubble.
    private let bubbleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        return l
    }()

    /// Haptic generator — prepared on touch begin for low-latency feedback.
    private let haptic = UISelectionFeedbackGenerator()

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isExclusiveTouch = true
        backgroundColor = .clear

        // Build letter labels
        for letter in letters {
            let label = UILabel()
            label.text = letter
            label.font = .systemFont(ofSize: 10, weight: .semibold)
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            label.isAccessibilityElement = true
            label.accessibilityIdentifier = "section-index-\(letter)"
            label.accessibilityLabel = "Jump to \(letter)"
            addSubview(label)
            letterLabels.append(label)
        }

        // Bubble setup
        bubbleEffect.contentView.addSubview(bubbleLabel)
        addSubview(bubbleEffect)

        updateLabelAppearance()
    }

    // MARK: Intrinsic Size

    override var intrinsicContentSize: CGSize {
        CGSize(width: railWidth, height: UIView.noIntrinsicMetric)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let letterHeight = bounds.height / CGFloat(letters.count)
        for (i, label) in letterLabels.enumerated() {
            label.frame = CGRect(
                x: 0,
                y: CGFloat(i) * letterHeight,
                width: railWidth,
                height: letterHeight
            )
        }

        // Size the bubble label to fill the effect view.
        bubbleLabel.frame = bubbleEffect.contentView.bounds
    }

    // MARK: Available Letters Update

    func updateAvailable(_ newSet: Set<String>) {
        guard newSet != availableLetters else { return }
        availableLetters = newSet
        updateLabelAppearance()
    }

    func updateSelectionBehavior(_ canSelectUnavailableLetters: Bool) {
        guard canSelectUnavailableLetters != self.canSelectUnavailableLetters else { return }
        self.canSelectUnavailableLetters = canSelectUnavailableLetters
        updateLabelAppearance()
    }

    // MARK: Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        haptic.prepare()
        if let touch = touches.first {
            handleTouch(at: touch.location(in: self))
        }
        showBubble()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if let touch = touches.first {
            handleTouch(at: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        endTouch()
    }

    // MARK: Touch → Letter Mapping

    /// Converts a Y position within the control to a letter index, updates
    /// the active letter, fires haptics, and calls the coordinator callback.
    private func handleTouch(at point: CGPoint) {
        let letterHeight = bounds.height / CGFloat(letters.count)
        let index = max(0, min(Int(point.y / letterHeight), letters.count - 1))
        let letter = letters[index]

        guard letter != activeLetter else { return }
        activeLetter = letter

        updateLabelAppearance()
        positionBubble(for: index, letterHeight: letterHeight)

        if availableLetters.contains(letter) || canSelectUnavailableLetters {
            haptic.selectionChanged()
            haptic.prepare() // re-arm for next transition
            coordinator?.onScrollTo(letter)
        }
    }

    private func endTouch() {
        activeLetter = nil
        hideBubble()
        updateLabelAppearance()
    }

    // MARK: Bubble

    private func showBubble() {
        UIView.animate(withDuration: 0.15) {
            self.bubbleEffect.alpha = 1
        }
    }

    private func hideBubble() {
        UIView.animate(withDuration: 0.2) {
            self.bubbleEffect.alpha = 0
        }
    }

    private func positionBubble(for index: Int, letterHeight: CGFloat) {
        let centerY = (CGFloat(index) + 0.5) * letterHeight
        bubbleEffect.center = CGPoint(
            x: (railWidth / 2) - bubbleOffset,
            y: centerY
        )
        bubbleLabel.text = letters[index]
        bubbleLabel.frame = bubbleEffect.contentView.bounds
    }

    // MARK: Label Styling

    /// Refreshes every label's opacity, color, and transform to reflect
    /// the current `activeLetter` and `availableLetters` state.
    private func updateLabelAppearance() {
        for (i, label) in letterLabels.enumerated() {
            let letter = letters[i]
            let isActive = letter == activeLetter
            let isAvailable = availableLetters.contains(letter)

            if isActive {
                label.textColor = UIColor.tintColor
                label.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            } else {
                let opacity = isAvailable ? 0.78 : (canSelectUnavailableLetters ? 0.45 : 0.2)
                label.textColor = UIColor.label.withAlphaComponent(opacity)
                label.transform = .identity
            }
        }
    }
}
#endif
