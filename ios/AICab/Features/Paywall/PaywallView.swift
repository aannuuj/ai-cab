import SwiftUI
import StoreKit
import AICabCore
import AICabDesign

/// Honest-trial paywall: timeline of what happens when, reminder toggle, one clear CTA.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let source: PaywallSource
    var onClose: (() -> Void)?

    @State private var selectedID = PurchaseManager.ProductID.yearly
    @State private var showAllPlans = false
    @State private var purchasing = false
    @State private var closeVisible = false

    private var purchases: PurchaseManager { model.purchases }
    private var selected: Product? { purchases.products.first { $0.id == selectedID } }
    /// Before products load (or offline), show the standard 3-day trial so the screen never looks broken.
    private var trialDays: Int? {
        if purchases.products.isEmpty { return selectedID == PurchaseManager.ProductID.yearly ? 3 : nil }
        return purchases.trialDays(for: selected)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.charcoal.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(trialDays != nil ? "Enjoy your free trial" : "Unlock AI-Cab Pro")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 56)

                    if let days = trialDays {
                        TrialTimeline(steps: timeline(days: days))
                    } else {
                        benefits
                    }

                    if showAllPlans || trialDays == nil {
                        plans
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { footer }

            if closeVisible {
                Button {
                    model.resolve(.paywall, .dismissed)
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 40, height: 40)
                }
                .glassCircle()
                .padding(.leading, 16)
                .padding(.top, 8)
                .transition(.opacity)
                .accessibilityLabel("Close")
            }
        }
        .task {
            if purchases.products.isEmpty { await purchases.loadProducts() }
            try? await Task.sleep(for: .seconds(source == .onboarding ? 2 : 0.4))
            withAnimation { closeVisible = true }
        }
        .onChange(of: purchases.isPro) { _, isPro in
            if isPro { close() }
        }
        .interactiveDismissDisabled(source == .onboarding)
    }

    // MARK: Sections

    private func timeline(days: Int) -> [TrialTimeline.Step] {
        let calendar = Calendar.current
        let now = Date()
        let reminder = calendar.date(byAdding: .day, value: max(days - 1, 0), to: now) ?? now
        let member = calendar.date(byAdding: .day, value: days, to: now) ?? now
        let style = Date.FormatStyle().month(.abbreviated).day(.twoDigits)
        return [
            .init(symbol: "checkmark", title: "Install the app", subtitle: "Set it up to match your goals", isDone: true),
            .init(symbol: "lock.open", title: "Today: Free trial starts",
                  subtitle: "Every topic, Research depth, all 10 Path units and themes, free for \(days) days."),
            .init(symbol: "bell", title: "\(reminder.formatted(style)): Trial reminder", subtitle: "We'll let you know it's ending soon."),
            .init(symbol: "crown", title: "\(member.formatted(style)): Become a member", subtitle: "Your trial converts unless you cancel.", isFinal: true),
        ]
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 18) {
            benefit("square.grid.2x2.fill", "All 20 topics", "Agents, RAG, evals, chips, interpretability and more")
            benefit("dial.high.fill", "Research-depth definitions", "The maths and the papers behind every term")
            benefit("map.fill", "All 10 Path units", "From tokens to frontier research")
            benefit("paintpalette.fill", "Themes & clean shares", "Feed themes, card styles, no watermark")
            benefit("sparkles", "AI-drafted words", "Add any term you hear; we write the definitions")
        }
        .padding(20)
        .tactileCard()
    }

    private func benefit(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.teal)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var plans: some View {
        VStack(spacing: 12) {
            ForEach(purchases.products, id: \.id) { product in
                PlanRow(product: product,
                        badge: product.id == PurchaseManager.ProductID.yearly ? "Best value" : nil,
                        detail: detail(for: product),
                        selected: product.id == selectedID) {
                    selectedID = product.id
                }
            }
            if purchases.products.isEmpty {
                unavailableNotice
            }
        }
    }

    private var unavailableNotice: some View {
        HStack(spacing: 8) {
            if purchases.isLoading {
                ProgressView().tint(Palette.textSecondary)
                Text("Loading prices…")
            } else {
                Image(systemName: "wifi.exclamationmark")
                Text("Couldn't reach the App Store.")
                Button("Retry") { Task { await purchases.loadProducts() } }
                    .foregroundStyle(Palette.teal)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if trialDays != nil {
                Toggle(isOn: Binding(get: { model.preferences.trialReminderEnabled }, set: { model.setTrialReminder($0) })) {
                    Text("Reminder before trial ends").font(.body).foregroundStyle(Palette.textPrimary)
                }
                .tint(Palette.lime)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Capsule().fill(Palette.surface))
            }

            Button {
                Task { await buy() }
            } label: {
                HStack(spacing: 10) {
                    if purchasing { ProgressView().tint(Palette.ink) }
                    Text(ctaTitle)
                }
            }
            .buttonStyle(PrimaryButtonStyle(.teal))
            .disabled(selected == nil || purchasing)

            if let selected {
                Text(priceLine(for: selected))
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            } else if purchases.products.isEmpty && !showAllPlans {
                unavailableNotice
            }
            if let error = purchases.lastError {
                Text(error).font(.footnote).foregroundStyle(Palette.coral)
            }

            HStack {
                Button("Restore") { Task { await purchases.restore() } }
                Spacer()
                if trialDays != nil {
                    Button(showAllPlans ? "Hide plans" : "All plans") { withAnimation { showAllPlans.toggle() } }
                    Spacer()
                }
                Button("Terms") { openURL(model.config.termsURL) }
                Spacer()
                Button("Privacy") { openURL(model.config.privacyURL) }
            }
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 12)
        .background(
            LinearGradient(colors: [Palette.charcoal.opacity(0), Palette.charcoal, Palette.charcoal], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    // MARK: Logic

    private var ctaTitle: String {
        guard let selected else { return trialDays != nil ? "Start free trial" : "Continue" }
        if trialDays != nil { return "Try for \(purchases.zeroPrice(like: selected))" }
        return selected.type == .nonConsumable ? "Unlock forever" : "Continue"
    }

    private func priceLine(for product: Product) -> String {
        if let monthly = purchases.monthlyEquivalent(of: product) {
            let lead = trialDays.map { "\($0) days free, then " } ?? ""
            return "\(lead)\(monthly), billed yearly as \(product.displayPrice)/year"
        }
        if product.type == .nonConsumable { return "\(product.displayPrice) once. Yours forever." }
        return "\(product.displayPrice)/month. Cancel anytime."
    }

    private func detail(for product: Product) -> String {
        if let monthly = purchases.monthlyEquivalent(of: product) { return "\(product.displayPrice)/year · \(monthly)" }
        if product.type == .nonConsumable { return "\(product.displayPrice) one-time" }
        return "\(product.displayPrice)/month"
    }

    private func buy() async {
        guard let selected else { return }
        purchasing = true
        defer { purchasing = false }
        if await purchases.purchase(selected) {
            model.resolve(.paywall, .accepted)
            await model.rescheduleNotifications()
            close()
        }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}

private struct PlanRow: View {
    let product: Product
    let badge: String?
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Palette.teal : Palette.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName).font(.headline).foregroundStyle(Palette.textPrimary)
                    Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if let badge {
                    Text(badge).font(.caption.bold()).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Palette.lime))
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? Palette.teal : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}
