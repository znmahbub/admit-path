import Foundation

struct ProgramRepository {
    let catalog: CatalogData

    func allPrograms() -> [Program] {
        catalog.programs.sorted { lhs, rhs in
            if lhs.countryName(using: self) != rhs.countryName(using: self) {
                return lhs.countryName(using: self) < rhs.countryName(using: self)
            }
            return lhs.universityName < rhs.universityName
        }
    }

    func allUniversities() -> [University] {
        catalog.universities
    }

    func university(id: String) -> University? {
        catalog.universities.first { $0.id == id }
    }

    func program(id: String) -> Program? {
        catalog.programs.first { $0.id == id }
    }

    func requirement(for programID: String) -> ProgramRequirement? {
        catalog.requirements.first { $0.programID == programID }
    }

    func deadlines(for programID: String) -> [ProgramDeadline] {
        catalog.deadlines
            .filter { $0.programID == programID }
            .sorted { $0.applicationDeadline < $1.applicationDeadline }
    }

    func nextDeadline(for programID: String, from date: Date = .now) -> ProgramDeadline? {
        deadlines(for: programID).first { $0.applicationDeadline >= date }
            ?? deadlines(for: programID).first
    }

    func country(for programID: String) -> String {
        guard let program = program(id: programID),
              let university = university(id: program.universityID) else {
            return "Unknown"
        }
        return university.country
    }

    func savedPrograms(in state: DemoState) -> [Program] {
        catalog.programs.filter { state.savedProgramIDs.contains($0.id) }
    }

    func comparedPrograms(in state: DemoState) -> [Program] {
        catalog.programs.filter { state.comparisonProgramIDs.contains($0.id) }
    }

    func isSaved(programID: String, in state: DemoState) -> Bool {
        state.savedProgramIDs.contains(programID)
    }

    func isCompared(programID: String, in state: DemoState) -> Bool {
        state.comparisonProgramIDs.contains(programID)
    }

    func save(programID: String, in state: inout DemoState) {
        state.savedProgramIDs.insert(programID)
    }

    func unsave(programID: String, in state: inout DemoState) {
        state.savedProgramIDs.remove(programID)
    }

    func toggleCompared(programID: String, in state: inout DemoState, limit: Int = 4) {
        if state.comparisonProgramIDs.contains(programID) {
            state.comparisonProgramIDs.remove(programID)
            return
        }
        if state.comparisonProgramIDs.count >= limit, let existing = state.comparisonProgramIDs.first {
            state.comparisonProgramIDs.remove(existing)
        }
        state.comparisonProgramIDs.insert(programID)
    }
}

private extension Program {
    func countryName(using repository: ProgramRepository) -> String {
        repository.university(id: universityID)?.country ?? "Unknown"
    }
}
