import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var hasStarted = false
    @Published var stepIndex = 0
    @Published var draftProfile: StudentProfile

    let environment: AppEnvironment
    let steps = ["Student Profile", "Academic History", "Tests & Funding", "Destinations"]

    init(profile: StudentProfile?, environment: AppEnvironment) {
        self.draftProfile = profile ?? .empty
        self.environment = environment
    }

    var estimatedProgramCount: Int {
        environment.matchingService.rankedPrograms(
            profile: stagedProfile,
            filters: .empty,
            universities: environment.catalog.universities,
            programs: environment.catalog.programs,
            requirements: environment.catalog.requirements,
            deadlines: environment.catalog.deadlines,
            scholarships: estimatedScholarships
        ).count
    }

    var estimatedScholarshipCount: Int {
        estimatedScholarships.filter { $0.level != .unlikely }.count
    }

    var canAdvance: Bool {
        stepValidationMessage == nil
    }

    var stepValidationMessage: String? {
        switch stepIndex {
        case 0:
            if draftProfile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Add the student's name to personalize matching and community guidance."
            }
            if draftProfile.subjectArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Choose a subject area so AdmitPath can rank programs realistically."
            }
            return nil
        case 1:
            if draftProfile.degreeLevel == .undergrad && (draftProfile.secondaryResultPercent ?? 0) <= 0 {
                return "Enter HSC/A-Level/IB results for undergraduate matching."
            }
            if draftProfile.degreeLevel == .masters && (draftProfile.gpaValue <= 0 || draftProfile.gpaScale <= 0) {
                return "Enter a valid undergraduate GPA and grading scale."
            }
            return nil
        case 2:
            if draftProfile.englishTestType != .none && draftProfile.englishTestScore <= 0 {
                return "Add an English-language test score, or switch the test type to None."
            }
            if draftProfile.tuitionBudgetUSD <= 0 && draftProfile.tuitionBudgetBDT <= 0 {
                return "Add at least one tuition budget figure."
            }
            return nil
        case 3:
            if draftProfile.preferredCountries.isEmpty {
                return "Select at least one target country."
            }
            return nil
        default:
            return nil
        }
    }

    var progress: Double {
        Double(stepIndex + 1) / Double(steps.count)
    }

    var stagedProfile: StudentProfile {
        var profile = draftProfile
        profile.onboardingComplete = true
        return profile
    }

    func nextStep() {
        stepIndex = min(stepIndex + 1, steps.count - 1)
    }

    func previousStep() {
        stepIndex = max(stepIndex - 1, 0)
    }

    private var estimatedScholarships: [ScholarshipMatch] {
        environment.scholarshipService.rankedScholarships(
            profile: stagedProfile,
            scholarships: environment.catalog.scholarships
        )
    }
}
