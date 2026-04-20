import Foundation

struct HomeViewModel {
    let snapshot: HomeSnapshot
    let displayName: String

    var greeting: String {
        displayName == "there" ? "Welcome to AdmitPath" : "Welcome back, \(displayName)"
    }

    var urgencySubtitle: String {
        if let planner = snapshot.upcomingPlannerItems.first {
            return "\(planner.title) • \(relativeDaysString(to: planner.date))"
        }
        guard let deadline = snapshot.nextDeadline else {
            return "No live applications yet."
        }
        return "\(deadline.universityName) due \(formatDate(deadline.targetDeadline))"
    }
}
