import Foundation

enum ApplicationSystem: String, Codable, CaseIterable, Identifiable {
    case commonApp = "Common App"
    case ucas = "UCAS"
    case direct = "Direct Apply"

    var id: String { rawValue }
}

struct RequirementItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var isComplete: Bool
}

struct EssayProject: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var prompt: String
    var wordTarget: Int
    var completionPercent: Int
}

struct FamilyFundingPlan: Codable, Hashable {
    var guardianContributionUSD: Int
    var savingsUSD: Int
    var monthlyBudgetUSD: Int
    var needsLoanSupport: Bool

    static let empty = FamilyFundingPlan(
        guardianContributionUSD: 0,
        savingsUSD: 0,
        monthlyBudgetUSD: 0,
        needsLoanSupport: false
    )

    var totalAvailableUSD: Int {
        guardianContributionUSD + savingsUSD
    }
}

struct AffordabilityScenario: Codable, Hashable, Identifiable {
    var id: String
    var country: String
    var totalCostUSD: Int
    var familyContributionUSD: Int
    var scholarshipSupportUSD: Int
    var netCostAfterScholarshipsUSD: Int
    var remainingGapUSD: Int
    var requiresLoanSupport: Bool
    var netCostSummary: String
}

struct ReadinessScore: Codable, Hashable {
    var overall: Int
    var profile: Int
    var testing: Int
    var essays: Int
    var applications: Int
    var funding: Int
    var blockers: [String]

    static let empty = ReadinessScore(
        overall: 0,
        profile: 0,
        testing: 0,
        essays: 0,
        applications: 0,
        funding: 0,
        blockers: []
    )
}

enum MatchConfidence: String, Codable, Hashable {
    case low
    case medium
    case high
}

struct FitReasonItem: Codable, Hashable, Identifiable {
    var id: String
    var label: String
    var detail: String
    var score: Int
}

enum CommunityGroupKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case country = "Country"
    case major = "Major"
    case intake = "Intake"
    case applicationSystem = "Application System"
    case funding = "Funding"

    var id: String { rawValue }
}

struct CommunityGroup: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var kind: CommunityGroupKind
    var memberCount: Int
    var postCount: Int
    var isRecommended: Bool
}

struct FeedAttachment: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var kind: String
    var url: String?
}

struct Reaction: Codable, Hashable, Identifiable {
    var id: String
    var emoji: String
    var count: Int
}

struct ReputationEvent: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var points: Int
    var createdAt: Date
}

struct ModerationAction: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var status: ModerationStatus
    var createdAt: Date
}

struct FeedRankingContext: Codable, Hashable {
    var relevanceScore: Int
    var trustScore: Int
    var engagementScore: Int
    var freshnessScore: Int
    var totalScore: Int
}

struct FeedPost: Hashable, Identifiable {
    var post: PeerPost
    var author: PeerProfile?
    var ranking: FeedRankingContext
    var trustBadge: String?
    var attachments: [FeedAttachment]
    var reactions: [Reaction]

    var id: String { post.id }
}
