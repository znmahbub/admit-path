import Foundation

struct SettingsViewModel {
    let profile: StudentProfile?
    let notifications: NotificationPreferences

    var intakeSummary: String {
        profile?.targetIntake ?? "No intake selected"
    }

    var demoIdentity: String {
        profile?.fullName.isEmpty == false ? (profile?.fullName ?? "Local Demo User") : "Local Demo User"
    }

    var focusSummary: String {
        guard let profile else { return "No focus selected" }
        return "\(profile.degreeLevel.rawValue) • \(profile.subjectArea)"
    }
}
