import Foundation

struct ResetService {
    private let sopGenerationService = SOPGenerationService()

    func emptyState() -> DemoState {
        .empty
    }

    func sampleState(from catalog: CatalogData) -> DemoState {
        let sampleProgram = catalog.programs.first(where: { $0.id.contains("toronto_metropolitan") })
            ?? catalog.programs.first(where: { $0.degreeLevel == .masters })
            ?? catalog.programs.first

        let answers = sopGenerationService.makeAnswers(from: [
            "I became interested in analytics after seeing inconsistent decisions improve when teams used structured evidence.",
            "My undergraduate coursework in statistics, finance, and economics built the quantitative foundation I need for graduate study.",
            "I have worked on reporting and analysis projects that required clean communication, judgment, and practical execution.",
            "Canada offers employability, a diverse international student base, and a practical taught Master's structure that fits my goals.",
            "I am looking for a program with applied modules, employer links, and a community where Bangladeshi students can learn from peers already inside the system.",
            "In the short term I want an analytics role; in the long term I want to build teams making evidence-based decisions in Bangladesh and the wider region."
        ])

        let project = sampleProgram.map { program in
            sopGenerationService.makeProject(
                existing: nil,
                title: "Master SOP",
                mode: .programSpecific,
                profile: catalog.sampleProfile,
                program: program,
                scholarship: nil,
                answers: answers
            )
        }

        return DemoState(
            profile: catalog.sampleProfile,
            savedProgramIDs: Set(catalog.programs.prefix(4).map(\.id)),
            comparisonProgramIDs: Set(catalog.programs.prefix(2).map(\.id)),
            trackedScholarshipIDs: Set(catalog.scholarships.prefix(3).map(\.id)),
            applications: catalog.sampleApplications,
            tasks: catalog.sampleTasks,
            plannerItems: [],
            sopProjects: project.map { [$0] } ?? [],
            bookmarkedPostIDs: Set(catalog.peerPosts.prefix(2).map(\.id)),
            reports: [],
            filters: .empty,
            notifications: .default,
            lastGeneratedNotifications: []
        )
    }
}
