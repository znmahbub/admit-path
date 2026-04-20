import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct AffordabilityServiceTests {
    @Test
    func scenariosCaptureGapAndScholarshipStack() {
        let service = AffordabilityService()
        let profile = StudentProfile(
            id: "student_finance",
            fullName: "Funding User",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            secondaryResultPercent: 90,
            gpaValue: 0,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.0,
            workExperienceYears: 0,
            scholarshipNeeded: true,
            annualBudgetUSD: 24000,
            tuitionBudgetUSD: 18000,
            preferredCountries: ["United States", "Canada"],
            familyFundingPlan: FamilyFundingPlan(
                guardianContributionUSD: 14000,
                savingsUSD: 6000,
                monthlyBudgetUSD: 500,
                needsLoanSupport: true
            ),
            onboardingComplete: true
        )
        let program = Program(
            id: "program_finance",
            universityID: "uni_finance",
            universityName: "Example University",
            name: "BS Computer Science",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            durationMonths: 48,
            tuitionUSD: 28000,
            applicationFeeUSD: 75,
            officialURL: "https://example.org/program",
            summary: "Example program",
            intakeTerms: ["Fall 2027"],
            scholarshipAvailable: true,
            estimatedLivingCostUSD: 12000,
            totalCostOfAttendanceUSD: 40000
        )
        let scholarships = [
            ScholarshipMatch(
                scholarship: Scholarship(
                    id: "sch_finance",
                    name: "Global Scholar",
                    sponsor: "Example Sponsor",
                    destinationCountries: ["United States"],
                    eligibleNationalities: ["Bangladesh"],
                    eligibleSubjects: ["Computer Science"],
                    eligibleDegreeLevels: [.undergrad],
                    minSecondaryPercent: 85,
                    coverageType: .partialTuition,
                    maxAmountUSD: 10000,
                    officialURL: "https://example.org/scholarship",
                    summary: "Scholarship summary",
                    deadline: .now.addingTimeInterval(60 * 60 * 24 * 21),
                    needBased: true
                ),
                level: .likelyEligible,
                reason: "Strong academic fit",
                projectedGapUSD: 6000
            )
        ]

        let scenario = service.scenario(
            for: profile,
            program: program,
            scholarships: scholarships,
            country: "United States"
        )

        #expect(scenario.totalCostUSD == 40000)
        #expect(scenario.familyContributionUSD == 20000)
        #expect(scenario.scholarshipSupportUSD == 10000)
        #expect(scenario.remainingGapUSD == 10000)
        #expect(scenario.requiresLoanSupport)
        #expect(scenario.netCostSummary.contains("remaining gap"))
    }
}
