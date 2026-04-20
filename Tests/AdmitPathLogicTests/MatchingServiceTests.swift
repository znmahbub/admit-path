import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct MatchingServiceTests {
    @Test
    func fitBandMappingMatchesExpandedSpec() {
        let service = MatchingService()

        #expect(service.fitBand(for: 82) == .realistic)
        #expect(service.fitBand(for: 60) == .target)
        #expect(service.fitBand(for: 40) == .ambitious)
    }

    @Test
    func rankingPrefersProgramThatFitsCountryBudgetAndSubject() throws {
        let service = MatchingService()
        let profile = StudentProfile(
            id: "student_test",
            fullName: "Test User",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .masters,
            subjectArea: "Business Analytics",
            gpaValue: 3.7,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.5,
            workExperienceYears: 2,
            scholarshipNeeded: true,
            annualBudgetUSD: 38000,
            tuitionBudgetUSD: 25000,
            preferredCountries: ["United Kingdom"],
            onboardingComplete: true
        )
        let university = University(
            id: "uni_one",
            name: "Example University",
            country: "United Kingdom",
            city: "Leeds",
            websiteURL: "https://example.org",
            rankingBucket: "Top 200",
            type: "Public"
        )
        let program = Program(
            id: "program_one",
            universityID: university.id,
            universityName: university.name,
            name: "MSc Business Analytics",
            degreeLevel: .masters,
            subjectArea: "Business Analytics",
            durationMonths: 12,
            tuitionUSD: 22000,
            applicationFeeUSD: 80,
            officialURL: "https://example.org/program",
            summary: "A strong analytics program.",
            intakeTerms: ["Fall 2027"],
            scholarshipAvailable: true,
            estimatedLivingCostUSD: 12000,
            totalCostOfAttendanceUSD: 34000
        )
        let requirement = ProgramRequirement(
            id: "req_one",
            programID: program.id,
            minGPAValue: 3.0,
            minGPAScale: 4.0,
            ieltsMin: 6.5,
            toeflMin: 88,
            duolingoMin: 120,
            sopRequired: true,
            cvRequired: true,
            lorCount: 2,
            transcriptRequired: true,
            passportRequired: true
        )
        let deadline = ProgramDeadline(
            id: "deadline_one",
            programID: program.id,
            intakeTerm: "Fall 2027",
            applicationDeadline: Date().addingTimeInterval(60 * 60 * 24 * 30)
        )
        let scholarship = Scholarship(
            id: "sch_one",
            name: "Example Scholarship",
            sponsor: "Test Sponsor",
            destinationCountries: ["United Kingdom"],
            eligibleNationalities: ["Bangladesh"],
            eligibleSubjects: ["Business Analytics"],
            eligibleDegreeLevels: [.masters],
            minGPAValue: 3.0,
            coverageType: .partialTuition,
            maxAmountUSD: 8000,
            officialURL: "https://example.org/scholarship",
            summary: "Scholarship summary",
            deadline: Date().addingTimeInterval(60 * 60 * 24 * 10),
            needBased: true
        )
        let scholarships = ScholarshipService().rankedScholarships(profile: profile, scholarships: [scholarship])

        let results = service.rankedPrograms(
            profile: profile,
            filters: .empty,
            universities: [university],
            programs: [program],
            requirements: [requirement],
            deadlines: [deadline],
            scholarships: scholarships
        )

        let first = try #require(results.first)
        #expect(results.count == 1)
        #expect(first.fitBand == .realistic)
        #expect(first.estimatedFundingGapUSD == 0)
        #expect(first.score >= 78)
    }

    @Test
    func undergradMatchingUsesSecondaryScore() throws {
        let service = MatchingService()
        let profile = StudentProfile(
            id: "student_undergrad",
            fullName: "Undergrad User",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            secondaryResultPercent: 91.0,
            gpaValue: 0,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.0,
            workExperienceYears: 0,
            scholarshipNeeded: true,
            annualBudgetUSD: 32000,
            tuitionBudgetUSD: 22000,
            preferredCountries: ["Australia"],
            onboardingComplete: true
        )
        let university = University(
            id: "uni_undergrad",
            name: "Example Undergrad University",
            country: "Australia",
            city: "Melbourne",
            websiteURL: "https://example.org",
            type: "Public"
        )
        let program = Program(
            id: "undergrad_program",
            universityID: university.id,
            universityName: university.name,
            name: "BSc Computer Science",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            durationMonths: 48,
            tuitionUSD: 21000,
            applicationFeeUSD: 60,
            officialURL: "https://example.org/cs",
            summary: "Undergraduate CS program.",
            intakeTerms: ["Fall 2027"],
            scholarshipAvailable: true,
            estimatedLivingCostUSD: 10000,
            totalCostOfAttendanceUSD: 31000
        )
        let requirement = ProgramRequirement(
            id: "req_undergrad",
            programID: program.id,
            minGPAValue: 0,
            minGPAScale: 4.0,
            minSecondaryPercent: 85.0,
            ieltsMin: 6.0,
            sopRequired: true,
            cvRequired: false,
            lorCount: 1,
            transcriptRequired: true,
            passportRequired: true
        )

        let results = service.rankedPrograms(
            profile: profile,
            filters: .empty,
            universities: [university],
            programs: [program],
            requirements: [requirement],
            deadlines: [],
            scholarships: []
        )

        let first = try #require(results.first)
        #expect(first.fitBand != .ambitious)
        #expect(first.score > 55)
    }

    @Test
    func matchesIncludeExplainableFitLedgerConfidenceAndFundingSignals() throws {
        let service = MatchingService()
        let profile = StudentProfile(
            id: "student_explainable",
            fullName: "Explainable User",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            secondaryResultPercent: 93.0,
            gpaValue: 0,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.5,
            workExperienceYears: 0,
            scholarshipNeeded: true,
            annualBudgetUSD: 30000,
            tuitionBudgetUSD: 22000,
            preferredCountries: ["United States"],
            familyFundingPlan: FamilyFundingPlan(
                guardianContributionUSD: 15000,
                savingsUSD: 5000,
                monthlyBudgetUSD: 400,
                needsLoanSupport: true
            ),
            onboardingComplete: true
        )
        let university = University(
            id: "uni_explainable",
            name: "Example University",
            country: "United States",
            city: "Boston",
            websiteURL: "https://example.org",
            type: "Private"
        )
        let program = Program(
            id: "program_explainable",
            universityID: university.id,
            universityName: university.name,
            name: "BS Computer Science",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            durationMonths: 48,
            tuitionUSD: 26000,
            applicationFeeUSD: 80,
            officialURL: "https://example.org/program",
            summary: "Example program.",
            intakeTerms: ["Fall 2027"],
            scholarshipAvailable: true,
            estimatedLivingCostUSD: 14000,
            totalCostOfAttendanceUSD: 40000,
            dataFreshness: "Updated This Week"
        )
        let requirement = ProgramRequirement(
            id: "req_explainable",
            programID: program.id,
            minGPAValue: 0,
            minGPAScale: 4.0,
            minSecondaryPercent: 88.0,
            ieltsMin: 6.5,
            satMin: 1350,
            sopRequired: true,
            cvRequired: false,
            lorCount: 2,
            transcriptRequired: true,
            passportRequired: true
        )
        let deadline = ProgramDeadline(
            id: "deadline_explainable",
            programID: program.id,
            intakeTerm: "Fall 2027",
            applicationDeadline: Date().addingTimeInterval(60 * 60 * 24 * 35)
        )
        let scholarship = Scholarship(
            id: "sch_explainable",
            name: "Merit Award",
            sponsor: "Example Sponsor",
            destinationCountries: ["United States"],
            eligibleNationalities: ["Bangladesh"],
            eligibleSubjects: ["Computer Science"],
            eligibleDegreeLevels: [.undergrad],
            minSecondaryPercent: 90.0,
            coverageType: .partialTuition,
            maxAmountUSD: 12000,
            officialURL: "https://example.org/scholarship",
            summary: "Scholarship summary",
            deadline: Date().addingTimeInterval(60 * 60 * 24 * 15),
            needBased: true
        )
        let scholarships = ScholarshipService().rankedScholarships(profile: profile, scholarships: [scholarship])

        let results = service.rankedPrograms(
            profile: profile,
            filters: .empty,
            universities: [university],
            programs: [program],
            requirements: [requirement],
            deadlines: [deadline],
            scholarships: scholarships
        )

        let first = try #require(results.first)
        #expect(first.fitReasonLedger.count >= 5)
        #expect(first.confidence == .high)
        #expect(first.sourceFreshness == "Updated This Week")
        #expect(first.netCostEstimateUSD == 28000)
        #expect(first.affordabilityScenario?.remainingGapUSD == 8000)
        #expect(first.explanation.contains("Fit ledger"))
    }
}
