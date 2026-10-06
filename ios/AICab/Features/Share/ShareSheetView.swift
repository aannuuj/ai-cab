import SwiftUI
import Photos
import AICabCore
import AICabDesign

/// Share a word as a styled card: preview, round quick actions (theme, save, collection, copy, watermark)
/// and share targets (Messages, Stories, WhatsApp, the system sheet).
struct ShareSheetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let term: Term

    @State private var theme: ShareCardTheme = .paper
    @State private var showWatermark = true
    @State private var editingTheme = false
    @State private var savedToPhotos = false
    @State private var copied = false
    @State private var newCollectionName = ""
    @State private var creatingCollection = false

    var body: some View {
        let preview = renderUIImage()
        VStack(spacing: 20) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(Palette.textPrimary).frame(width: 46, height: 46)
                }
                .glassCircle()
                .accessibilityLabel("Close")
                Spacer()
            }

            Group {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(theme.background)
                        .aspectRatio(4 / 5, contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
            .padding(.horizontal, 28)
            .animation(.easeInOut, value: theme)
            .frame(maxHeight: .infinity)

            if editingTheme {
                themePicker
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .top, spacing: 0) {
                RoundAction(title: "Style", symbol: "paintbrush.pointed", isOn: editingTheme) {
                    withAnimation(.snappy) { editingTheme.toggle() }
                }
                RoundAction(title: savedToPhotos ? "Saved" : "Save", symbol: savedToPhotos ? "checkmark" : "arrow.down.to.line") {
                    saveToPhotos()
                }
                collectionMenu
                RoundAction(title: copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = shareMessage
                    copied = true
                }
                RoundAction(title: showWatermark ? "No logo" : "Show logo",
                            symbol: showWatermark ? "drop" : "drop.fill", locked: !model.isPro, isOn: !showWatermark) {
                    if model.isPro { showWatermark.toggle() } else { model.sheet = .paywall(.shareTheme) }
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .top, spacing: 0) {
                ShareTarget(title: "Messages", symbol: "message.fill", colors: [Color(hex: 0x5BF675), Color(hex: 0x0CBD2A)]) {
                    open("sms:&body=\(encoded(shareMessage))")
                }
                if model.config.facebookAppID != nil {
                    ShareTarget(title: "Stories", symbol: "camera.circle", colors: [Color(hex: 0xF58529), Color(hex: 0xDD2A7B), Color(hex: 0x8134AF)]) {
                        shareToStories()
                    }
                }
                ShareTarget(title: "WhatsApp", symbol: "phone.bubble.fill", colors: [Color(hex: 0x5FFC7B), Color(hex: 0x28D146)]) {
                    open("whatsapp://send?text=\(encoded(shareMessage))")
                }
                if let preview {
                    let image = Image(uiImage: preview)
                    ShareLink(item: image, subject: Text(term.term), message: Text(shareMessage),
                              preview: SharePreview(term.term, image: image)) {
                        ShareTarget.label(title: "More", symbol: "square.and.arrow.up", colors: [Palette.surfaceRaised, Palette.surface])
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Metrics.gutter)
        .background(Palette.charcoalDeep.ignoresSafeArea())
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: savedToPhotos)
        .sensoryFeedback(.success, trigger: copied)
        .alert("New collection", isPresented: $creatingCollection) {
            TextField("Name", text: $newCollectionName)
            Button("Create") {
                model.createCollection(named: newCollectionName, with: term.id)
                newCollectionName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var themePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(ShareCardTheme.allCases) { option in
                    Button {
                        if option.isPremium && !model.isPro { model.sheet = .paywall(.shareTheme) } else { theme = option }
                    } label: {
                        Chip(option.title, systemImage: option.isPremium && !model.isPro ? "lock" : nil, isSelected: theme == option)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Metrics.gutter)
    }

    private var collectionMenu: some View {
        let inAny = model.state.collections.contains { $0.termIds.contains(term.id) }
        return Menu {
            ForEach(model.state.collections) { collection in
                Button {
                    model.toggle(term.id, in: collection.id)
                } label: {
                    Label(collection.name, systemImage: collection.termIds.contains(term.id) ? "checkmark.circle.fill" : "circle")
                }
            }
            Divider()
            Button("New collection…", systemImage: "plus") { creatingCollection = true }
        } label: {
            RoundAction.label(title: "Collect", symbol: inAny ? "folder.fill" : "folder.badge.plus", locked: false, isOn: inAny)
        }
        .frame(maxWidth: .infinity)
    }

    private var shareMessage: String {
        "\(term.term) (\(term.pos)): \(term.definition(at: .beginner))\n\nLearning AI words with AI-Cab"
    }

    private func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=?+"))) ?? ""
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        openURL(url)
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

/// Round glass quick action with a caption ("Save image", "Copy text"…).
private struct RoundAction: View {
    let title: String
    let symbol: String
    var locked = false
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { Self.label(title: title, symbol: symbol, locked: locked, isOn: isOn) }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
    }

    static func label(title: String, symbol: String, locked: Bool, isOn: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOn ? Palette.ink : Palette.textPrimary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 56, height: 56)
                .background(Circle().fill(isOn ? Palette.teal : Palette.surface))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1)))
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Palette.gold))
                            .offset(x: 2, y: -2)
                    }
                }
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// App-coloured share destination.
private struct ShareTarget: View {
    let title: String
    let symbol: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) { Self.label(title: title, symbol: symbol, colors: colors) }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
    }

    static func label(title: String, symbol: String, colors: [Color]) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)))
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(Palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
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
                Text("(\(term.pos)) \(term.definition(at: level))")
                    .font(.system(size: 21))
                    .lineLimit(7)
                    .minimumScaleFactor(0.7)
                if let example = term.example {
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.system(size: 16, design: .serif).italic())
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
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
        .frame(width: 360, height: 450)
    }
}
