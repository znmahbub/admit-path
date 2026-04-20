import Foundation

struct VerificationRequestRecord: Codable, Hashable, Identifiable {
    var id: String
    var userID: String
    var userEmail: String?
    var note: String
    var createdAt: Date
    var status: ModerationStatus

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case userEmail = "userEmail"
        case note
        case createdAt
        case status
    }
}

struct CatalogFreshnessItem: Hashable, Identifiable {
    var id: String { program.id }
    var program: Program
    var country: String
}

struct AdminDashboardSnapshot: Hashable {
    var reports: [CommunityReport]
    var verificationRequests: [VerificationRequestRecord]
    var stalePrograms: [CatalogFreshnessItem]

    static let empty = AdminDashboardSnapshot(
        reports: [],
        verificationRequests: [],
        stalePrograms: []
    )
}
