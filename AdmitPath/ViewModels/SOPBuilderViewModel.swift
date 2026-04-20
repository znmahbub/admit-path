import Combine
import Foundation

@MainActor
final class SOPBuilderViewModel: ObservableObject {
    @Published var selectedProgramID: String?
    @Published var selectedScholarshipID: String?
    @Published var mode: SOPProjectMode
    @Published var answerTexts: [String]
    @Published var generatedOutline: [String] = []
    @Published var generatedDraft = ""
    @Published var critiqueFlags: [SOPCritiqueFlag] = []
    @Published var versions: [SOPVersion] = []
    @Published var isGenerating = false
    @Published var generationError: String?

    let service: SOPGenerationService

    init(project: SOPProject? = nil, selectedProgramID: String? = nil, service: SOPGenerationService) {
        self.service = service
        self.selectedProgramID = project?.programID ?? selectedProgramID
        self.selectedScholarshipID = project?.scholarshipID
        self.mode = project?.mode ?? .master
        self.answerTexts = project?.questionnaireAnswers.map(\.answer) ?? Array(repeating: "", count: service.questions.count)
        self.generatedOutline = project?.generatedOutline ?? []
        self.generatedDraft = project?.generatedDraft ?? ""
        self.critiqueFlags = project?.critiqueFlags ?? []
        self.versions = project?.versions ?? []
    }

    var answers: [SOPQuestionAnswer] {
        service.makeAnswers(from: answerTexts)
    }

    func generate(
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship?,
        gateway: SOPGateway
    ) async {
        isGenerating = true
        generationError = nil

        do {
            let generated = try await gateway.generate(
                profile: profile,
                program: program,
                scholarship: scholarship,
                mode: mode,
                answers: answers
            )
            generatedOutline = generated.outline
            generatedDraft = generated.draft
            critiqueFlags = generated.critiqueFlags
        } catch {
            generationError = error.localizedDescription
        }

        isGenerating = false
    }

    func rewrite(_ action: SOPRewriteAction) {
        generatedDraft = service.rewrite(draft: generatedDraft, action: action)
        critiqueFlags = service.critique(draft: generatedDraft, answers: answers, mode: mode)
    }
}
