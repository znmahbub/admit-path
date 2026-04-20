import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.97, green: 0.98, blue: 1.00)
    static let backgroundBottom = Color(red: 0.90, green: 0.94, blue: 0.99)
    static let background = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let cardBackground = Color.white.opacity(0.92)
    static let elevatedBackground = Color.white
    static let primary = Color(red: 0.10, green: 0.23, blue: 0.51)
    static let primarySoft = Color(red: 0.87, green: 0.92, blue: 0.99)
    static let primaryTint = Color(red: 0.14, green: 0.34, blue: 0.69)
    static let slate = Color(red: 0.25, green: 0.31, blue: 0.39)
    static let ink = Color(red: 0.14, green: 0.18, blue: 0.25)
    static let border = Color.white.opacity(0.72)
    static let teal = Color(red: 0.05, green: 0.56, blue: 0.60)
    static let gold = Color(red: 0.83, green: 0.62, blue: 0.18)
    static let success = Color(red: 0.17, green: 0.52, blue: 0.36)
    static let warning = Color(red: 0.83, green: 0.55, blue: 0.08)
    static let danger = Color(red: 0.78, green: 0.22, blue: 0.20)
    static let subtleText = Color(red: 0.42, green: 0.47, blue: 0.54)
    static let secondaryText = Color(red: 0.32, green: 0.37, blue: 0.45)
    static let shadow = Color.black.opacity(0.08)
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.23, blue: 0.51),
            Color(red: 0.08, green: 0.45, blue: 0.63)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let canvasGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let largeRadius: CGFloat = 28
    static let cardRadius: CGFloat = 22
    static let compactRadius: CGFloat = 16
    static let sectionSpacing: CGFloat = 22
}

extension FitBand {
    var tint: Color {
        switch self {
        case .realistic: AppTheme.success
        case .target: AppTheme.primary
        case .ambitious: AppTheme.warning
        }
    }
}

extension ApplicationStatus {
    var tint: Color {
        switch self {
        case .shortlisted: AppTheme.primary
        case .researching: AppTheme.teal
        case .preparingDocs: AppTheme.warning
        case .readyToApply: AppTheme.success
        case .submitted: AppTheme.primary
        case .interview: AppTheme.warning
        case .decisionReceived: AppTheme.success
        }
    }
}

extension ScholarshipMatchLevel {
    var tint: Color {
        switch self {
        case .likelyEligible: AppTheme.success
        case .possible: AppTheme.warning
        case .unlikely: AppTheme.danger
        }
    }
}

extension VerificationStatus {
    var tint: Color {
        switch self {
        case .unverified: AppTheme.subtleText
        case .verifiedStudent: AppTheme.primary
        case .verifiedAdmit: AppTheme.success
        case .verifiedAlumni: AppTheme.gold
        }
    }
}

extension ModerationStatus {
    var tint: Color {
        switch self {
        case .clear: AppTheme.success
        case .underReview: AppTheme.warning
        case .limited: AppTheme.danger
        }
    }
}
