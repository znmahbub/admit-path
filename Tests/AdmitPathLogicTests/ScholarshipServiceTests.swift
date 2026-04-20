import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct ScholarshipServiceTests {
    @Test
    func likelyEligibleScholarshipRanksAboveUnlikely() throws {
        let profile = StudentProfile(
            id: "student_test",
            fullName: "Nadia",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .masters,
            subjectArea: "Finance",
            gpaValue: 3.8,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.5,
            workExperienceYears: 2,
            scholarshipNeeded: true,
            annualBudgetUSD: 32000,
            tuitionBudgetUSD: 22000,
            preferredCountries: ["United Kingdom"],
            onboardingComplete: true
        )
        let likely = Scholarship(
            id: "likely",
            name: "Likely Scholarship",
            sponsor: "Sponsor",
            destinationCountries: ["United Kingdom"],
            eligibleNationalities: ["Bangladesh"],
            eligibleSubjects: ["Finance"],
            eligibleDegreeLevels: [.masters],
            minGPAValue: 3.3,
            coverageType: .partialTuition,
            maxAmountUSD: 10000,
            officialURL: "https://example.org",
            summary: "Summary",
            deadline: Date(),
            needBased: true
        )
        let unlikely = Scholarship(
            id: "unlikely",
            name: "Unlikely Scholarship",
            sponsor: "Sponsor",
            destinationCountries: ["Canada"],
            eligibleNationalities: ["Nepal"],
            eligibleSubjects: ["Public Policy"],
            eligibleDegreeLevels: [.masters],
            minGPAValue: 3.9,
            coverageType: .partialTuition,
            maxAmountUSD: 5000,
            officialURL: "https://example.org",
            summary: "Summary",
            deadline: Date().addingTimeInterval(5000),
            needBased: false
        )

        let results = ScholarshipService().rankedScholarships(profile: profile, scholarships: [unlikely, likely])

        let first = try #require(results.first)
        let last = try #require(results.last)
        #expect(first.scholarship.id == "likely")
        #expect(first.level == ScholarshipMatchLevel.likelyEligible)
        #expect(last.level == ScholarshipMatchLevel.unlikely)
    }

    @Test
    func undergradScholarshipCanUseSecondaryThreshold() throws {
        let profile = StudentProfile(
            id: "student_undergrad",
            fullName: "Tania",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .undergrad,
            subjectArea: "Engineering",
            secondaryResultPercent: 90.0,
            gpaValue: 0,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.0,
            workExperienceYears: 0,
            scholarshipNeeded: true,
            annualBudgetUSD: 28000,
            tuitionBudgetUSD: 20000,
            preferredCountries: ["Australia"],
            onboardingComplete: true
        )
        let scholarship = Scholarship(
            id: "undergrad_scholarship",
            name: "Undergrad Scholarship",
            sponsor: "Sponsor",
            destinationCountries: ["Australia"],
            eligibleNationalities: ["Bangladesh"],
            eligibleSubjects: ["Engineering"],
            eligibleDegreeLevels: [.undergrad],
            minSecondaryPercent: 85.0,
            coverageType: .partialTuition,
            maxAmountUSD: 7000,
            officialURL: "https://example.org",
            summary: "Summary",
            deadline: Date(),
            needBased: true
        )

        let results = ScholarshipService().rankedScholarships(profile: profile, scholarships: [scholarship])
        let first = try #require(results.first)
        #expect(first.level == ScholarshipMatchLevel.likelyEligible)
    }
}
