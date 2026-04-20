import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct SOPGenerationServiceTests {
    @Test
    func outlineDraftAndCritiqueWorkWithPartialAnswers() {
        let service = SOPGenerationService()
        let profile = StudentProfile(
            id: "student_test",
            fullName: "Nadia",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .masters,
            subjectArea: "Data Science",
            gpaValue: 3.6,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.5,
            workExperienceYears: 1,
            scholarshipNeeded: true,
            annualBudgetUSD: 35000,
            tuitionBudgetUSD: 24000,
            preferredCountries: ["Canada"],
            onboardingComplete: true
        )
        let answers = service.makeAnswers(from: [
            "I became interested in data because evidence can improve decisions.",
            "",
            "I worked on dashboard and reporting projects.",
            "Canada offers strong applied Master's programs.",
            "",
            "I want an analyst role first and leadership later."
        ])

        let outline = service.generateOutline(profile: profile, program: nil, mode: .master, answers: answers)
        let draft = service.generateDraft(profile: profile, program: nil, mode: .master, answers: answers)
        let critique = service.critique(draft: draft, answers: answers, mode: .master)

        #expect(outline.count == 6)
        #expect(!draft.isEmpty)
        #expect(draft.contains("Data Science"))
        #expect(!critique.isEmpty)
    }

    @Test
    func makeProjectCreatesVersionHistory() {
        let service = SOPGenerationService()
        let profile = StudentProfile.empty
        let answers = service.makeAnswers(from: Array(repeating: "Test answer with enough detail to avoid empty content.", count: service.questions.count))
        let project = service.makeProject(
            existing: nil,
            title: "Master SOP",
            mode: .master,
            profile: profile,
            program: nil,
            scholarship: nil,
            answers: answers
        )

        #expect(project.versions.count == 1)
        #expect(!project.generatedDraft.isEmpty)
    }
}
