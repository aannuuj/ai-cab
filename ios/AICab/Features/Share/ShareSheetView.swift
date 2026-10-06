import SwiftUI
import Photos
import AICabCore
import AICabDesign

/// Share a word as a styled card: preview, themes, watermark, Save to Photos, Stories and the system sheet.
struct ShareSheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let term: Term

    @State private var theme: ShareCardTheme = .paper
    @State private var showWatermark = true
    @State private var savedToPhotos = false
    @State private var rendered: Image?

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.textPrimary).frame(width: 46, height: 46)
                }
                .glassCircle()
                .accessibilityLabel("Close")
                Spacer()
            }

            ShareCardView(term: term, level: model.level, theme: theme, showWatermark: showWatermark)
                .aspectRatio(4 / 5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                .padding(.horizontal, 12)
                .animation(.easeInOut, value: theme)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    Button {
                        if model.isPro { showWatermark.toggle() } else { model.sheet = .paywall(.shareTheme) }
                    } label: {
                        Chip("Watermark", systemImage: showWatermark ? "eye" : "eye.slash", isSelected: !showWatermark)
                    }
                    Button { saveToPhotos() } label: {
                        Chip(savedToPhotos ? "Saved" : "Save to Photos", systemImage: savedToPhotos ? "checkmark" : "arrow.down.to.line")
                    }
                    ForEach(ShareCardTheme.allCases) { option in
                        Button {
                            if option.isPremium && !model.isPro { model.sheet = .paywall(.shareTheme) } else { theme = option }
                        } label: {
                            Chip(option.title, systemImage: option.isPremium && !model.isPro ? "lock" : "paintpalette", isSelected: theme == option)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Metrics.gutter)

            HStack(spacing: 22) {
                if model.config.facebookAppID != nil {
                    shareTarget("Stories", symbol: "plus.circle", colors: [Color(hex: 0xF58529), Color(hex: 0xDD2A7B), Color(hex: 0x8134AF)]) {
                        shareToStories()
                    }
                }
                if let image = renderedImage() {
                    ShareLink(item: image, subject: Text(term.term), message: Text(shareMessage),
                              preview: SharePreview(term.term, image: image)) {
                        targetLabel("More", symbol: "ellipsis", colors: [Palette.surfaceRaised, Palette.surface])
                    }
                }
                ShareLink(item: shareMessage) {
                    targetLabel("Text", symbol: "text.bubble", colors: [Palette.teal, Palette.tealDeep])
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(Metrics.gutter)
        .background(Palette.charcoalDeep.ignoresSafeArea())
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: savedToPhotos)
    }

    private var shareMessage: String {
        "\(term.term) (\(term.pos)): \(term.definition(at: .beginner))\n\nLearning AI words with AI-Cab"
    }

    private func shareTarget(_ title: String, symbol: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) { targetLabel(title, symbol: symbol, colors: colors) }
            .buttonStyle(.plain)
    }

    private func targetLabel(_ title: String, symbol: String, colors: [Color]) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)))
            Text(title).font(.footnote).foregroundStyle(Palette.textSecondary)
        }
    }

    @MainActor
    private func renderUIImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            ShareCardView(term: term, level: model.level, theme: theme, showWatermark: showWatermark)
                .frame(width: 360, height: 450)
        )
        renderer.scale = 3
        return renderer.uiImage
    }

    private func renderedImage() -> Image? {
        renderUIImage().map { Image(uiImage: $0) }
    }

    private func saveToPhotos() {
        guard let image = renderUIImage() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            Task { @MainActor in savedToPhotos = true }
        }
    }

    private func shareToStories() {
        guard let appID = model.config.facebookAppID, let image = renderUIImage(), let data = image.pngData(),
              let url = URL(string: "instagram-stories://share?source_application=\(appID)") else { return }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.stickerImage": data,
              "com.instagram.sharedSticker.backgroundTopColor": "#2A2A2C",
              "com.instagram.sharedSticker.backgroundBottomColor": "#1C1C1E"]],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )
        openURL(url)
    }
}

enum ShareCardTheme: String, CaseIterable, Identifiable {
    case paper, night, teal, coral

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var isPremium: Bool { self == .teal || self == .coral }

    var background: Color {
        switch self {
        case .paper: Palette.paper
        case .night: Palette.charcoalDeep
        case .teal: Palette.teal
        case .coral: Palette.coral
        }
    }

    var foreground: Color { self == .night ? Palette.textPrimary : Palette.ink }
}

/// The shareable card itself (also rendered to an image).
struct ShareCardView: View {
    let term: Term
    let level: Level
    let theme: ShareCardTheme
    let showWatermark: Bool

    var body: some View {
        ZStack {
            theme.background
            if theme != .night {
                Halftone(color: Palette.ink.opacity(0.06), spacing: 9, dot: 1.6)
            }
            VStack(alignment: .leading, spacing: 18) {
                Spacer()
                Text(term.term)
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Rectangle().fill(theme.foreground.opacity(0.25)).frame(height: 1.5)
                Text("\(term.pos) \(term.definition(at: level))")
                    .font(.system(size: 21))
                    .fixedSize(horizontal: false, vertical: true)
                if let example = term.example {
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.system(size: 16, design: .serif).italic())
                        .opacity(0.7)
                }
                if showWatermark {
                    HStack(spacing: 8) {
                        AppMark(size: 28)
                        Text("AI-Cab").font(.system(size: 17, weight: .semibold))
                    }
                    .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
                    .background(Capsule().fill(theme.foreground.opacity(0.08)))
                    .padding(.top, 6)
                }
                Spacer()
            }
            .foregroundStyle(theme.foreground)
            .padding(32)
        }
    }
}
