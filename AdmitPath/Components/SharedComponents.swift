import SwiftUI

struct AppCanvas<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackgroundView())
    }
}

struct AppBackgroundView: View {
    var body: some View {
        AppTheme.canvasGradient
            .overlay(
                VStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.06))
                        .frame(width: 280, height: 280)
                        .blur(radius: 30)
                        .offset(x: -120, y: -130)
                    Spacer()
                }
            )
            .ignoresSafeArea()
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }
}

struct HeroCard<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.semibold))
                        .kerning(0.8)
                        .foregroundStyle(.white.opacity(0.78))
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer(minLength: 0)
                accessory
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.largeRadius, style: .continuous))
        .shadow(color: AppTheme.primary.opacity(0.20), radius: 18, x: 0, y: 12)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.subtleText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous)
                .fill(color.opacity(0.10))
        )
    }
}

struct SectionTitle: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
            }
        }
    }
}

struct FitBadge: View {
    let band: FitBand

    var body: some View {
        Text(band.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(band.tint.opacity(0.14))
            .foregroundStyle(band.tint)
            .clipShape(Capsule())
    }
}

struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct SummaryPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

struct AppNoticeBanner: View {
    let state: AppLaunchState
    let dismiss: () -> Void
    let retry: () -> Void

    var body: some View {
        guard let notice = state.notice else {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.isBlocking ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .foregroundStyle(state.isBlocking ? AppTheme.warning : AppTheme.primary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title)
                        .font(.headline)
                    Text(notice.message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.subtleText)
                }
                Spacer()
                if state.isBlocking {
                    Button("Retry", action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                } else {
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.subtleText)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
        )
    }
}

struct SyncStatusBanner: View {
    let status: SyncStatus
    let retry: () -> Void

    var body: some View {
        switch status {
        case .localGuest, .synced:
            EmptyView()
        case .restoring, .syncing, .requiresNetwork, .failed:
            HStack(alignment: .top, spacing: 12) {
                Group {
                    switch status {
                    case .restoring:
                        ProgressView()
                            .progressViewStyle(.circular)
                    case .syncing:
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    case .requiresNetwork:
                        Image(systemName: "wifi.exclamationmark")
                    case .failed:
                        Image(systemName: "exclamationmark.triangle.fill")
                    case .localGuest, .synced:
                        EmptyView()
                    }
                }
                .foregroundStyle(iconTint)
                .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(status.summary)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.subtleText)
                }

                Spacer()

                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }

    private var title: String {
        switch status {
        case .restoring:
            return "Restoring your workspace"
        case .syncing:
            return "Syncing latest changes"
        case .requiresNetwork:
            return "Read-only until connectivity returns"
        case .failed:
            return "Cloud sync needs attention"
        case .localGuest, .synced:
            return ""
        }
    }

    private var iconTint: Color {
        switch status {
        case .requiresNetwork, .failed:
            return AppTheme.warning
        case .restoring, .syncing:
            return AppTheme.primary
        case .localGuest, .synced:
            return AppTheme.primary
        }
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?

    init(title: String, message: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        SurfaceCard {
            Label(title, systemImage: "sparkles.rectangle.stack.fill")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleText)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.subtleText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct TimelineRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let trailing: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}

struct LaunchRecoveryView: View {
    let state: AppLaunchState
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "server.rack")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.primary)
            Text(state.notice?.title ?? "AdmitPath could not start")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(state.notice?.message ?? "The app could not load its local demo data.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtleText)
                .multilineTextAlignment(.center)
            Button("Retry loading data", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.largeRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.largeRadius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackgroundView())
    }
}

extension View {
    @ViewBuilder
    func appInlineNavigationTitle() -> some View {
        #if os(macOS)
        self
        #else
        self.navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    func appDecimalFieldStyle() -> some View {
        #if os(macOS)
        self.textFieldStyle(.roundedBorder)
        #else
        self.keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
        #endif
    }

    @ViewBuilder
    func appNumericFieldStyle() -> some View {
        #if os(macOS)
        self.textFieldStyle(.roundedBorder)
        #else
        self.keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
        #endif
    }
}
