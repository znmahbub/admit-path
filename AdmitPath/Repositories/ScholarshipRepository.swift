import Foundation

struct ScholarshipRepository {
    let catalog: CatalogData

    func allScholarships() -> [Scholarship] {
        catalog.scholarships.sorted { $0.deadline < $1.deadline }
    }

    func scholarship(id: String) -> Scholarship? {
        catalog.scholarships.first { $0.id == id }
    }

    func trackedScholarships(in state: DemoState) -> [Scholarship] {
        catalog.scholarships.filter { state.trackedScholarshipIDs.contains($0.id) }
    }

    func toggleTrackedScholarship(id: String, in state: inout DemoState) {
        if state.trackedScholarshipIDs.contains(id) {
            state.trackedScholarshipIDs.remove(id)
        } else {
            state.trackedScholarshipIDs.insert(id)
        }
    }
}
