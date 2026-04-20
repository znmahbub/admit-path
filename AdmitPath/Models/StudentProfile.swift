import Foundation

struct ApplicantDocumentStatus: Codable, Hashable {
    var sopDraftReady: Bool
    var cvReady: Bool
    var lorsReady: Bool
    var transcriptReady: Bool
    var englishScoreReady: Bool
    var passportReady: Bool
    var financialsReady: Bool
    var scholarshipEssayReady: Bool
    var portfolioReady: Bool

    static let empty = ApplicantDocumentStatus(
        sopDraftReady: false,
        cvReady: false,
        lorsReady: false,
        transcriptReady: false,
        englishScoreReady: false,
        passportReady: false,
        financialsReady: false,
        scholarshipEssayReady: false,
        portfolioReady: false
    )
}

struct ApplicantProfile: Codable, Hashable, Identifiable {
    var id: String
    var fullName: String
    var nationality: String
    var currentCountry: String
    var homeCity: String = "Dhaka"
    var targetIntake: String
    var degreeLevel: DegreeLevel
    var subjectArea: String
    var secondaryCurriculum: SecondaryCurriculum = .bangladeshHSC
    var secondaryResultPercent: Double? = nil
    var undergraduateInstitution: String = ""
    var gpaValue: Double
    var gpaScale: Double
    var englishTestType: EnglishTestType
    var englishTestScore: Double
    var satScore: Int? = nil
    var greScore: Int? = nil
    var gmatScore: Int? = nil
    var workExperienceYears: Int
    var scholarshipNeeded: Bool
    var annualBudgetUSD: Int
    var tuitionBudgetUSD: Int
    var annualBudgetBDT: Int = 0
    var tuitionBudgetBDT: Int = 0
    var preferredCountries: [String]
    var targetCities: [String] = []
    var targetUniversityNames: [String] = []
    var activities: [String] = []
    var honors: [String] = []
    var intendedMajorCluster: String? = nil
    var counselorName: String? = nil
    var counselorEmail: String? = nil
    var standardizedTestStatus: String? = nil
    var essayReadinessNotes: String? = nil
    var familyFundingPlan: FamilyFundingPlan? = nil
    var documentStatus: ApplicantDocumentStatus = .empty
    var onboardingComplete: Bool

    static let empty = ApplicantProfile(
        id: "student_local",
        fullName: "",
        nationality: "Bangladesh",
        currentCountry: "Bangladesh",
        homeCity: "Dhaka",
        targetIntake: "Fall 2027",
        degreeLevel: .masters,
        subjectArea: "Business Analytics",
        secondaryCurriculum: .bangladeshHSC,
        secondaryResultPercent: 92,
        undergraduateInstitution: "",
        gpaValue: 3.4,
        gpaScale: 4.0,
        englishTestType: .ielts,
        englishTestScore: 7.0,
        satScore: nil,
        greScore: nil,
        gmatScore: nil,
        workExperienceYears: 0,
        scholarshipNeeded: true,
        annualBudgetUSD: 35000,
        tuitionBudgetUSD: 24000,
        annualBudgetBDT: 4_200_000,
        tuitionBudgetBDT: 2_900_000,
        preferredCountries: ["Canada", "United Kingdom"],
        targetCities: [],
        targetUniversityNames: [],
        documentStatus: .empty,
        onboardingComplete: false
    )

    var displayName: String {
        guard let first = fullName.split(separator: " ").first else {
            return "there"
        }
        let name = String(first)
        return name.isEmpty ? "there" : name
    }

    var completenessScore: Int {
        let requiredChecks: [Bool] = [
            !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !nationality.isEmpty,
            !currentCountry.isEmpty,
            !homeCity.isEmpty,
            !targetIntake.isEmpty,
            !subjectArea.isEmpty,
            degreeLevel == .undergrad ? (secondaryResultPercent ?? 0) > 0 : (gpaValue > 0 && gpaScale > 0),
            englishTestType != .none,
            englishTestScore > 0,
            (annualBudgetUSD > 0 || annualBudgetBDT > 0),
            (tuitionBudgetUSD > 0 || tuitionBudgetBDT > 0),
            !preferredCountries.isEmpty
        ]
        let completed = requiredChecks.filter { $0 }.count
        return Int((Double(completed) / Double(requiredChecks.count)) * 100.0)
    }

    var normalizedGPA: Double {
        guard gpaScale > 0 else { return 0 }
        return gpaValue / gpaScale
    }

    var normalizedAcademicStrength: Double {
        if degreeLevel == .undergrad {
            return (secondaryResultPercent ?? 0) / 100.0
        }
        return normalizedGPA
    }

    var effectiveAnnualBudgetUSD: Int {
        if annualBudgetUSD > 0 {
            return annualBudgetUSD
        }
        return Int(Double(annualBudgetBDT) / AppConstants.planningFXRateBDTPerUSD)
    }

    var effectiveTuitionBudgetUSD: Int {
        if tuitionBudgetUSD > 0 {
            return tuitionBudgetUSD
        }
        return Int(Double(tuitionBudgetBDT) / AppConstants.planningFXRateBDTPerUSD)
    }

    var resolvedFamilyFundingPlan: FamilyFundingPlan {
        guard let familyFundingPlan else {
            return FamilyFundingPlan(
                guardianContributionUSD: max(effectiveAnnualBudgetUSD - max(effectiveAnnualBudgetUSD / 4, 0), 0),
                savingsUSD: min(5000, effectiveAnnualBudgetUSD / 4),
                monthlyBudgetUSD: max(effectiveAnnualBudgetUSD / 24, 0),
                needsLoanSupport: scholarshipNeeded
            )
        }
        return familyFundingPlan
    }
}

typealias StudentProfile = ApplicantProfile

extension ApplicantProfile {
    enum CodingKeys: String, CodingKey {
        case id
        case fullName
        case nationality
        case currentCountry
        case homeCity
        case targetIntake
        case degreeLevel
        case subjectArea
        case secondaryCurriculum
        case secondaryResultPercent
        case undergraduateInstitution
        case gpaValue
        case gpaScale
        case englishTestType
        case englishTestScore
        case satScore
        case greScore
        case gmatScore
        case workExperienceYears
        case scholarshipNeeded
        case annualBudgetUSD
        case tuitionBudgetUSD
        case annualBudgetBDT
        case tuitionBudgetBDT
        case preferredCountries
        case targetCities
        case targetUniversityNames
        case activities
        case honors
        case intendedMajorCluster
        case counselorName
        case counselorEmail
        case standardizedTestStatus
        case essayReadinessNotes
        case familyFundingPlan
        case documentStatus
        case onboardingComplete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        nationality = try container.decode(String.self, forKey: .nationality)
        currentCountry = try container.decode(String.self, forKey: .currentCountry)
        homeCity = try container.decodeIfPresent(String.self, forKey: .homeCity) ?? "Dhaka"
        targetIntake = try container.decode(String.self, forKey: .targetIntake)
        degreeLevel = try container.decode(DegreeLevel.self, forKey: .degreeLevel)
        subjectArea = try container.decode(String.self, forKey: .subjectArea)
        secondaryCurriculum = try container.decodeIfPresent(SecondaryCurriculum.self, forKey: .secondaryCurriculum) ?? .bangladeshHSC
        secondaryResultPercent = try container.decodeIfPresent(Double.self, forKey: .secondaryResultPercent)
        undergraduateInstitution = try container.decodeIfPresent(String.self, forKey: .undergraduateInstitution) ?? ""
        gpaValue = try container.decode(Double.self, forKey: .gpaValue)
        gpaScale = try container.decode(Double.self, forKey: .gpaScale)
        englishTestType = try container.decode(EnglishTestType.self, forKey: .englishTestType)
        englishTestScore = try container.decode(Double.self, forKey: .englishTestScore)
        satScore = try container.decodeIfPresent(Int.self, forKey: .satScore)
        greScore = try container.decodeIfPresent(Int.self, forKey: .greScore)
        gmatScore = try container.decodeIfPresent(Int.self, forKey: .gmatScore)
        workExperienceYears = try container.decode(Int.self, forKey: .workExperienceYears)
        scholarshipNeeded = try container.decode(Bool.self, forKey: .scholarshipNeeded)
        annualBudgetUSD = try container.decode(Int.self, forKey: .annualBudgetUSD)
        tuitionBudgetUSD = try container.decode(Int.self, forKey: .tuitionBudgetUSD)
        annualBudgetBDT = try container.decodeIfPresent(Int.self, forKey: .annualBudgetBDT) ?? 0
        tuitionBudgetBDT = try container.decodeIfPresent(Int.self, forKey: .tuitionBudgetBDT) ?? 0
        preferredCountries = try container.decode([String].self, forKey: .preferredCountries)
        targetCities = try container.decodeIfPresent([String].self, forKey: .targetCities) ?? []
        targetUniversityNames = try container.decodeIfPresent([String].self, forKey: .targetUniversityNames) ?? []
        activities = try container.decodeIfPresent([String].self, forKey: .activities) ?? []
        honors = try container.decodeIfPresent([String].self, forKey: .honors) ?? []
        intendedMajorCluster = try container.decodeIfPresent(String.self, forKey: .intendedMajorCluster)
        counselorName = try container.decodeIfPresent(String.self, forKey: .counselorName)
        counselorEmail = try container.decodeIfPresent(String.self, forKey: .counselorEmail)
        standardizedTestStatus = try container.decodeIfPresent(String.self, forKey: .standardizedTestStatus)
        essayReadinessNotes = try container.decodeIfPresent(String.self, forKey: .essayReadinessNotes)
        familyFundingPlan = try container.decodeIfPresent(FamilyFundingPlan.self, forKey: .familyFundingPlan)
        documentStatus = try container.decodeIfPresent(ApplicantDocumentStatus.self, forKey: .documentStatus) ?? .empty
        onboardingComplete = try container.decode(Bool.self, forKey: .onboardingComplete)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(nationality, forKey: .nationality)
        try container.encode(currentCountry, forKey: .currentCountry)
        try container.encode(homeCity, forKey: .homeCity)
        try container.encode(targetIntake, forKey: .targetIntake)
        try container.encode(degreeLevel, forKey: .degreeLevel)
        try container.encode(subjectArea, forKey: .subjectArea)
        try container.encode(secondaryCurriculum, forKey: .secondaryCurriculum)
        try container.encodeIfPresent(secondaryResultPercent, forKey: .secondaryResultPercent)
        try container.encode(undergraduateInstitution, forKey: .undergraduateInstitution)
        try container.encode(gpaValue, forKey: .gpaValue)
        try container.encode(gpaScale, forKey: .gpaScale)
        try container.encode(englishTestType, forKey: .englishTestType)
        try container.encode(englishTestScore, forKey: .englishTestScore)
        try container.encodeIfPresent(satScore, forKey: .satScore)
        try container.encodeIfPresent(greScore, forKey: .greScore)
        try container.encodeIfPresent(gmatScore, forKey: .gmatScore)
        try container.encode(workExperienceYears, forKey: .workExperienceYears)
        try container.encode(scholarshipNeeded, forKey: .scholarshipNeeded)
        try container.encode(annualBudgetUSD, forKey: .annualBudgetUSD)
        try container.encode(tuitionBudgetUSD, forKey: .tuitionBudgetUSD)
        try container.encode(annualBudgetBDT, forKey: .annualBudgetBDT)
        try container.encode(tuitionBudgetBDT, forKey: .tuitionBudgetBDT)
        try container.encode(preferredCountries, forKey: .preferredCountries)
        try container.encode(targetCities, forKey: .targetCities)
        try container.encode(targetUniversityNames, forKey: .targetUniversityNames)
        try container.encode(activities, forKey: .activities)
        try container.encode(honors, forKey: .honors)
        try container.encodeIfPresent(intendedMajorCluster, forKey: .intendedMajorCluster)
        try container.encodeIfPresent(counselorName, forKey: .counselorName)
        try container.encodeIfPresent(counselorEmail, forKey: .counselorEmail)
        try container.encodeIfPresent(standardizedTestStatus, forKey: .standardizedTestStatus)
        try container.encodeIfPresent(essayReadinessNotes, forKey: .essayReadinessNotes)
        try container.encodeIfPresent(familyFundingPlan, forKey: .familyFundingPlan)
        try container.encode(documentStatus, forKey: .documentStatus)
        try container.encode(onboardingComplete, forKey: .onboardingComplete)
    }
}
