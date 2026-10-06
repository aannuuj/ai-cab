import SwiftUI
import AICabCore
import AICabDesign

/// Tap a term, then its meaning. Matched pairs turn teal; misses shake.
struct MatchGameView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let pairs: [MatchPair]
    let onFinish: (Int, Int) -> Void

    @State private var definitions: [MatchPair] = []
    @State private var selectedTerm: String?
    @State private var matched: Set<String> = []
    @State private var wrongFlash: String?
    @State private var mistakes = 0
    @State private var finished = false

    var body: some View {
        ZStack {
            Palette.charcoal.ignoresSafeArea()
            if finished {
                ResultView(correct: max(pairs.count - mistakes, 0), total: pairs.count, passMark: nil) { dismiss() }
            } else {
                board
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Close", systemImage: "xmark") { dismiss() } }
        }
        .onAppear { if definitions.isEmpty { definitions = pairs.shuffled() } }
        .sensoryFeedback(.success, trigger: matched.count)
        .sensoryFeedback(.error, trigger: mistakes)
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Match \(matched.count) of \(pairs.count)")
            Text("Tap a term, then its meaning")
                .font(.serifTitle2)
                .foregroundStyle(Palette.textPrimary)
            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(pairs) { pair in
                            tile(pair.term, id: pair.termId, isTerm: true, serif: true)
                        }
                    }
                    .frame(width: 128)
                    VStack(spacing: 12) {
                        ForEach(definitions) { pair in
                            tile(pair.definition, id: pair.termId, isTerm: false, serif: false)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(Metrics.gutter)
    }

    private func tile(_ text: String, id: String, isTerm: Bool, serif: Bool) -> some View {
        let done = matched.contains(id)
        let active = isTerm && selectedTerm == id
        let flashing = !isTerm && wrongFlash == id
        let fill: Color = done ? Palette.teal : (active ? Palette.cream : (flashing ? Palette.coral : Palette.surface))
        return Button {
            tap(id: id, isTerm: isTerm)
        } label: {
            Text(text)
                .font(serif ? .system(.headline, design: .serif) : .footnote)
                .foregroundStyle(done || active || flashing ? Palette.ink : Palette.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .buttonStyle(TactileButtonStyle(fill: fill, radius: 18))
        .disabled(done)
        .opacity(done ? 0.6 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fill)
    }

    private func tap(id: String, isTerm: Bool) {
        if isTerm {
            selectedTerm = id
            return
        }
        guard let term = selectedTerm else { return }
        if term == id {
            matched.insert(id)
            selectedTerm = nil
            if matched.count == pairs.count {
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    finished = true
                    onFinish(max(pairs.count - mistakes, 0), pairs.count)
                }
            }
        } else {
            mistakes += 1
            wrongFlash = id
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                wrongFlash = nil
            }
        }
    }
}
