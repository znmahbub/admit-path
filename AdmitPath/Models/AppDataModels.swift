import Foundation

struct AppLaunchNotice: Equatable, Hashable {
    var title: String
    var message: String
}

enum AppLaunchState: Equatable {
    case ready
    case warning(AppLaunchNotice)
    case failed(AppLaunchNotice)

    var notice: AppLaunchNotice? {
        switch self {
        case .ready:
            return nil
        case .warning(let notice), .failed(let notice):
            return notice
        }
    }

    var isBlocking: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

struct NotificationPreferences: Codable, Hashable {
    var deadlineReminders: Bool
    var dailyTaskReminders: Bool
    var scholarshipReminders: Bool
    var weeklyProgressSummary: Bool

    static let `default` = NotificationPreferences(
        deadlineReminders: true,
        dailyTaskReminders: true,
        scholarshipReminders: true,
        weeklyProgressSummary: false
    )
}

struct DemoState: Codable, Hashable {
    var profile: StudentProfile?
    var savedProgramIDs: Set<String>
    var comparisonProgramIDs: Set<String>
    var trackedScholarshipIDs: Set<String>
    var applications: [ApplicationRecord]
    var tasks: [ApplicationTask]
    var plannerItems: [PlannerItem]
    var sopProjects: [SOPProject]
    var bookmarkedPostIDs: Set<String>
    var reports: [CommunityReport]
    var userPosts: [PeerPost] = []
    var userReplies: [PeerReply] = []
    var userArtifacts: [PeerArtifact] = []
    var verificationRequests: [VerificationRequest] = []
    var filters: MatchFilters
    var notifications: NotificationPreferences
    var lastGeneratedNotifications: [NotificationItem]

    static let empty = DemoState(
        profile: nil,
        savedProgramIDs: [],
        comparisonProgramIDs: [],
        trackedScholarshipIDs: [],
        applications: [],
        tasks: [],
        plannerItems: [],
        sopProjects: [],
        bookmarkedPostIDs: [],
        reports: [],
        userPosts: [],
        userReplies: [],
        userArtifacts: [],
        verificationRequests: [],
        filters: .empty,
        notifications: .default,
        lastGeneratedNotifications: []
    )
}

struct BootstrapResult {
    var environment: AppEnvironment
    var initialState: DemoState
    var launchState: AppLaunchState
}

struct CatalogData: Hashable {
    var universities: [University]
    var programs: [Program]
    var requirements: [ProgramRequirement]
    var deadlines: [ProgramDeadline]
    var scholarships: [Scholarship]
    var peerProfiles: [PeerProfile]
    var peerPosts: [PeerPost]
    var peerReplies: [PeerReply]
    var peerArtifacts: [PeerArtifact]
    var sampleProfile: StudentProfile
    var sampleApplications: [ApplicationRecord]
    var sampleTasks: [ApplicationTask]

    static let empty = CatalogData(
        universities: [],
        programs: [],
        requirements: [],
        deadlines: [],
        scholarships: [],
        peerProfiles: [],
        peerPosts: [],
        peerReplies: [],
        peerArtifacts: [],
        sampleProfile: .empty,
        sampleApplications: [],
        sampleTasks: []
    )
}

struct HomeSnapshot: Hashable {
    var profileCompleteness: Int
    var readinessScore: ReadinessScore
    var applicationsInProgress: Int
    var savedProgramsCount: Int
    var completedTaskCount: Int
    var pendingTaskCount: Int
    var nextDeadline: ApplicationRecord?
    var dueSoonTasks: [ApplicationTask]
    var upcomingPlannerItems: [PlannerItem]
    var recommendedScholarships: [ScholarshipMatch]
    var topMatches: [ProgramMatch]
    var communityHighlights: [PeerPost]
    var featuredFeed: [FeedPost]
    var fundingScenarios: [AffordabilityScenario]
    var sopProgress: Int
    var continueTitle: String
    var continueSubtitle: String
}
