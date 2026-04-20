import Foundation

struct University: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var country: String
    var city: String
    var websiteURL: String
    var rankingBucket: String?
    var type: String
    var region: String = ""
    var featuredForBangladesh: Bool = true
}

struct Program: Codable, Hashable, Identifiable {
    var id: String
    var universityID: String
    var universityName: String
    var name: String
    var degreeLevel: DegreeLevel
    var subjectArea: String
    var durationMonths: Int
    var tuitionUSD: Int
    var applicationFeeUSD: Int
    var officialURL: String
    var summary: String
    var intakeTerms: [String]
    var scholarshipAvailable: Bool
    var applicationPortal: String = "University Portal"
    var studyMode: String = "Full Time"
    var estimatedLivingCostUSD: Int = 0
    var totalCostOfAttendanceUSD: Int = 0
    var dataFreshness: String = "Curated"
    var lastUpdatedAt: Date = .now
    var bangladeshFitNote: String = ""
}

struct ProgramRequirement: Codable, Hashable, Identifiable {
    var id: String
    var programID: String
    var minGPAValue: Double
    var minGPAScale: Double
    var minSecondaryPercent: Double?
    var ieltsMin: Double?
    var toeflMin: Double?
    var duolingoMin: Double?
    var satMin: Int?
    var greRequired: Bool = false
    var gmatRequired: Bool = false
    var sopRequired: Bool
    var cvRequired: Bool
    var lorCount: Int
    var transcriptRequired: Bool
    var passportRequired: Bool
    var financialProofRequired: Bool = true
    var portfolioRequired: Bool = false
    var notes: String = ""
}

struct ProgramDeadline: Codable, Hashable, Identifiable {
    var id: String
    var programID: String
    var intakeTerm: String
    var applicationDeadline: Date
    var scholarshipDeadline: Date?
    var depositDeadline: Date?
    var interviewWindowStart: Date? = nil
    var visaPrepStart: Date? = nil
    var decisionExpected: Date? = nil
    var notes: String = ""
}

struct MatchFilters: Codable, Hashable {
    var country: String?
    var subjectArea: String?
    var degreeLevel: DegreeLevel?
    var maxCostOfAttendance: Int?
    var scholarshipOnly: Bool
    var fitBand: FitBand?

    static let empty = MatchFilters(
        country: nil,
        subjectArea: nil,
        degreeLevel: nil,
        maxCostOfAttendance: nil,
        scholarshipOnly: false,
        fitBand: nil
    )
}

struct ProgramMatch: Identifiable, Hashable {
    let program: Program
    let country: String
    let requirement: ProgramRequirement?
    let nextDeadline: ProgramDeadline?
    let score: Int
    let fitBand: FitBand
    let explanation: String
    let scholarshipCount: Int
    let estimatedFundingGapUSD: Int
    let affordabilitySummary: String
    let fitReasonLedger: [FitReasonItem]
    let confidence: MatchConfidence
    let netCostEstimateUSD: Int
    let sourceFreshness: String
    let affordabilityScenario: AffordabilityScenario?

    var id: String { program.id }
}
