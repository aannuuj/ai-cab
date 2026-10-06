import SwiftUI
import AICabCore
import AICabDesign

/// Chapters laid out as isometric paths of six lessons each.
struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @State private var active: ActiveLesson?
    @State private var visibleChapter: Int?

    struct ActiveLesson: Identifiable {
        let chapter: Chapter
        let lesson: LessonKind
        var id: String { "\(chapter.number).\(lesson.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 56) {
                        header
                        ForEach(model.chapters) { chapter in
                            ChapterSection(chapter: chapter) { lesson in
                                open(lesson, in: chapter)
                            }
                            .id(chapter.number)
                            .onAppear { visibleChapter = chapter.number }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 160)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let current = model.journeyCurrent {
                        proxy.scrollTo(current.chapter.number, anchor: .top)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let current = model.journeyCurrent {
                        Button {
                            withAnimation(.snappy) { proxy.scrollTo(current.chapter.number, anchor: .top) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: (visibleChapter ?? 0) > current.chapter.number ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(Palette.coral)
                                Text("Chapter \(current.chapter.number)")
                                    .font(.headline)
                                    .foregroundStyle(Palette.textPrimary)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .glassCapsule(interactive: true)
                        .padding(.bottom, 96)
                        .opacity(visibleChapter == current.chapter.number ? 0 : 1)
                        .animation(.easeInOut, value: visibleChapter)
                    }
                }
            }
            .background(Palette.charcoal.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $active) { item in
                NavigationStack {
                    LessonView(chapter: item.chapter, lesson: item.lesson)
                }
            }
        }
        .onAppear {
            if !model.state.nudges.journeyIntroSeen {
                model.resolve(.journey, .accepted)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("Journey")
                .font(.serifLargeTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("Ten chapters from \u{201C}what's a token?\u{201D} to frontier research.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let current = model.journeyCurrent {
                Button {
                    open(current.lesson, in: current.chapter)
                } label: {
                    Label("Continue: \(current.lesson.title)", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(.teal))
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func open(_ lesson: LessonKind, in chapter: Chapter) {
        if chapter.isPremium && !model.isPro {
            model.sheet = .paywall(.lockedChapter)
            return
        }
        switch model.lessonStatus(lesson, in: chapter) {
        case .locked: break
        case .available, .completed: active = ActiveLesson(chapter: chapter, lesson: lesson)
        }
    }
}

/// "CHAPTER 2 / Feelings You Can't Explain" + zig-zag path of tiles + floating decorations.
private struct ChapterSection: View {
    @Environment(AppModel.self) private var model
    let chapter: Chapter
    let onSelect: (LessonKind) -> Void

    private let offsets: [CGFloat] = [0, 0.55, 0, -0.55, 0, 0.55]

    var body: some View {
        let unlocked = model.isUnlocked(chapter)
        let current = model.journeyCurrent
        VStack(spacing: 12) {
            Eyebrow("Chapter \(chapter.number)")
            Text(chapter.title)
                .font(.serifTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(chapter.subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 6) {
                if chapter.isPremium && !model.isPro {
                    Label("Pro", systemImage: "lock").font(.caption.weight(.semibold)).foregroundStyle(Palette.gold)
                }
                Text("\(model.journeyEngine.completedCount(in: chapter, progress: model.state.journey))/6 complete")
                    .font(.caption)
                    .foregroundStyle(Palette.textTertiary)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    decorations(width: width)
                    ForEach(1..<LessonKind.allCases.count, id: \.self) { index in
                        DashedConnector(from: point(index - 1, width: width), to: point(index, width: width))
                    }
                    ForEach(Array(LessonKind.allCases.enumerated()), id: \.element) { index, lesson in
                        let status = model.lessonStatus(lesson, in: chapter)
                        let isCurrent = current?.chapter.number == chapter.number && current?.lesson == lesson
                        let x = point(index, width: width).x
                        let y = point(index, width: width).y
                        Button { onSelect(lesson) } label: {
                            IsoLessonTile(symbol: lesson.symbol, state: tileState(status, isCurrent: isCurrent), size: 150)
                        }
                        .buttonStyle(TileButtonStyle())
                        .position(x: x, y: y)
                        .accessibilityLabel("\(lesson.title), \(statusLabel(status))")
                        .accessibilityHint(lesson.subtitle)
                        .overlay {
                            if isCurrent {
                                CurrentMarker(title: lesson.title)
                                    .position(x: x, y: y - 72)
                            }
                        }
                    }
                }
            }
            .frame(height: 70 + 5 * 92 + 70)
            .opacity(unlocked ? 1 : 0.55)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func point(_ index: Int, width: CGFloat) -> CGPoint {
        CGPoint(x: width / 2 + offsets[index] * width * 0.32, y: 70 + CGFloat(index) * 92)
    }

    @ViewBuilder
    private func decorations(width: CGFloat) -> some View {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 60, 70), (0.88, 210, 62), (0.1, 330, 58), (0.9, 430, 66)]
        ForEach(Array(chapter.decorations.prefix(spots.count).enumerated()), id: \.offset) { index, symbol in
            let spot = spots[index]
            Group {
                if index.isMultiple(of: 2) {
                    IsoObject(symbol: symbol, palette: index == 0 ? .cream : .teal, size: spot.2)
                } else {
                    IsoDisc(symbol: symbol, size: spot.2, tint: index == 1 ? Palette.teal : Palette.coral)
                }
            }
            .position(x: width * spot.0, y: spot.1)
            .opacity(0.9)
        }
    }

    private func tileState(_ status: LessonStatus, isCurrent: Bool) -> IsoLessonTile.State {
        if isCurrent { return .current }
        switch status {
        case .locked: return .locked
        case .available: return .available
        case .completed: return .completed
        }
    }

    private func statusLabel(_ status: LessonStatus) -> String {
        switch status {
        case .locked: "locked"
        case .available: "available"
        case .completed: "completed"
        }
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

private struct DashedConnector: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: from.x, y: from.y + 22))
            path.addLine(to: CGPoint(x: to.x, y: to.y - 22))
        }
        .stroke(Palette.textTertiary, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 10]))
    }
}

/// Bouncing "START" bubble above the current tile.
private struct CurrentMarker: View {
    let title: String
    @State private var bob = false

    var body: some View {
        Text("START")
            .font(.caption.weight(.heavy))
            .tracking(1.5)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Palette.coral))
            .overlay(Capsule().strokeBorder(Palette.outline, lineWidth: 2))
            .offset(y: bob ? -5 : 0)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: bob)
            .onAppear { bob = true }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
