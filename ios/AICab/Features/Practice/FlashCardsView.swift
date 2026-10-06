import SwiftUI
import AICabCore
import AICabDesign

/// Flip cards: word on the front, meaning on the back; "Know it" / "Still learning" feed spaced repetition.
struct FlashCardsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var deck: [Term] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var known = 0
    @State private var learning = 0

    var body: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            if let term = deck[safe: index] {
                VStack(spacing: 22) {
                    ProgressView(value: Double(index), total: Double(max(deck.count, 1)))
                        .tint(Palette.teal)
                    HStack {
                        Label("\(learning)", systemImage: "arrow.uturn.backward.circle")
                            .foregroundStyle(Palette.coral)
                        Spacer()
                        Text("\(index + 1) / \(deck.count)")
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Label("\(known)", systemImage: "checkmark.circle")
                            .foregroundStyle(Palette.teal)
                    }
                    .font(.subheadline.weight(.semibold).monospacedDigit())

                    FlashCard(term: term, level: model.level, flipped: flipped,
                              isSpeaking: model.speech.speakingID == term.id) {
                        model.speech.speak(term.term, id: term.id)
                    }
                    .id(term.id)
                    .onTapGesture { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { flipped.toggle() } }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(flipped ? "Shows the word" : "Shows the meaning")

                    Text(flipped ? "How did you do?" : "Tap the card to flip it")
                        .font(.footnote)
                        .foregroundStyle(Palette.textTertiary)

                    HStack(spacing: 14) {
                        Button { rate(term, knewIt: false) } label: {
                            Label("Still learning", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(PrimaryButtonStyle(.coral))
                        Button { rate(term, knewIt: true) } label: {
                            Label("Know it", systemImage: "checkmark")
                        }
                        .buttonStyle(PrimaryButtonStyle(.teal))
                    }
                }
                .padding(Metrics.gutter)
            } else if !deck.isEmpty {
                done
            } else {
                ContentUnavailableView("No cards yet", systemImage: "rectangle.on.rectangle.angled",
                                       description: Text("Save a few words from the Words tab, then come back."))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: index)
        .navigationTitle("Flash cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        .onAppear { if deck.isEmpty { deck = model.flashCardDeck() } }
        .sensoryFeedback(.selection, trigger: flipped)
        .sensoryFeedback(.success, trigger: known)
    }

    private var done: some View {
        VStack(spacing: 18) {
            Spacer()
            IsoObject(symbol: "rectangle.on.rectangle.angled", palette: .teal, size: 120)
            Text("Deck done")
                .font(.serifTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("\(known) known · \(learning) still learning.\nWords you're still learning come back in your reviews.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Shuffle a new deck") {
                deck = model.flashCardDeck()
                index = 0
                known = 0
                learning = 0
                flipped = false
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
            Button("Done") { dismiss() }
                .buttonStyle(QuietButtonStyle())
        }
        .padding(Metrics.gutter)
    }

    private func rate(_ term: Term, knewIt: Bool) {
        model.rateFlashCard(term, knewIt: knewIt)
        if knewIt { known += 1 } else { learning += 1 }
        flipped = false
        index += 1
    }
}

/// Two-sided card with a 3D flip.
private struct FlashCard: View {
    let term: Term
    let level: Level
    let flipped: Bool
    let isSpeaking: Bool
    let speak: () -> Void

    var body: some View {
        ZStack {
            front
                .opacity(flipped ? 0 : 1)
            back
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }

    private var front: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(term.term)
                .font(.wordDisplay)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
            if let expansion = term.expansion {
                Text(expansion)
                    .font(.system(.headline, design: .serif).italic())
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            PronunciationPill(ipa: term.ipa, colors: .forTheme(.cream), isSpeaking: isSpeaking, action: speak)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tactileCard(fill: Palette.cream, radius: 34)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(term.term, color: Palette.ink.opacity(0.6))
            Text("(\(term.pos)) \(term.definition(at: level))")
                .font(.definition)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let example = term.example {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tactileCard(fill: Palette.teal, radius: 34)
    }
}
