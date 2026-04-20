import Foundation

struct SOPQuestionAnswer: Codable, Hashable, Identifiable {
    var id: String
    var question: String
    var answer: String
}

struct SOPCritiqueFlag: Codable, Hashable, Identifiable {
    var id: String
    var type: SOPCritiqueFlagType
    var message: String
}

struct SOPVersion: Codable, Hashable, Identifiable {
    var id: String
    var versionNumber: Int
    var content: String
    var createdAt: Date
}

struct SOPProject: Codable, Hashable, Identifiable {
    var id: String
    var programID: String?
    var scholarshipID: String?
    var title: String
    var mode: SOPProjectMode
    var questionnaireAnswers: [SOPQuestionAnswer]
    var generatedOutline: [String]
    var generatedDraft: String
    var critiqueFlags: [SOPCritiqueFlag]
    var versions: [SOPVersion]
    var updatedAt: Date
}

struct NotificationItem: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var body: String
    var scheduledFor: Date
}
