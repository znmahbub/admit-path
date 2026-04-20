import Foundation

struct Scholarship: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var sponsor: String
    var destinationCountries: [String]
    var eligibleNationalities: [String]
    var eligibleSubjects: [String]
    var eligibleDegreeLevels: [DegreeLevel]
    var minGPAValue: Double?
    var minSecondaryPercent: Double?
    var coverageType: ScholarshipCoverageType
    var maxAmountUSD: Int?
    var officialURL: String
    var summary: String
    var deadline: Date
    var needBased: Bool
    var meritBased: Bool = true
    var lastUpdatedAt: Date = .now
    var essayPromptHint: String = ""
}

struct ScholarshipMatch: Identifiable, Hashable {
    let scholarship: Scholarship
    let level: ScholarshipMatchLevel
    let reason: String
    let projectedGapUSD: Int

    var id: String { scholarship.id }
}
