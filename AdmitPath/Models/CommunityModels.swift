import Foundation

struct AdmissionOutcome: Codable, Hashable, Identifiable {
    var id: String
    var universityName: String
    var programName: String
    var country: String
    var degreeLevel: DegreeLevel
    var intake: String
    var result: String
}

struct PeerProfile: Codable, Hashable, Identifiable {
    var id: String
    var displayName: String
    var nationality: String
    var currentCountry: String
    var role: PeerRole
    var verificationStatus: VerificationStatus
    var currentUniversity: String
    var currentProgram: String
    var bio: String
    var subjectAreas: [String]
    var targetCountries: [String]
    var reputationScore: Int
    var outcomes: [AdmissionOutcome]
}

struct PeerPost: Codable, Hashable, Identifiable {
    var id: String
    var authorID: String
    var title: String
    var body: String
    var kind: CommunityPostKind
    var country: String
    var subjectArea: String
    var degreeLevel: DegreeLevel
    var programID: String?
    var scholarshipID: String?
    var tags: [String]
    var moderationStatus: ModerationStatus
    var createdAt: Date
    var upvoteCount: Int
}

struct PeerReply: Codable, Hashable, Identifiable {
    var id: String
    var postID: String
    var authorID: String
    var body: String
    var createdAt: Date
    var moderationStatus: ModerationStatus
    var isAcceptedAnswer: Bool
}

struct PeerArtifact: Codable, Hashable, Identifiable {
    var id: String
    var authorID: String
    var programID: String?
    var title: String
    var summary: String
    var kind: PeerArtifactKind
    var country: String
    var subjectArea: String
    var degreeLevel: DegreeLevel
    var verificationStatus: VerificationStatus
    var moderationStatus: ModerationStatus
    var createdAt: Date
    var bulletHighlights: [String]
}

struct CommunityReport: Codable, Hashable, Identifiable {
    var id: String
    var postID: String
    var reason: String
    var createdAt: Date
    var status: ModerationStatus
}

struct VerificationRequest: Codable, Hashable, Identifiable {
    var id: String
    var note: String
    var createdAt: Date
    var status: ModerationStatus
}
