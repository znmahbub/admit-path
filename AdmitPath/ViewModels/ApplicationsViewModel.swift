import Foundation

struct ApplicationsViewModel {
    func groupedApplications(_ applications: [ApplicationRecord]) -> [(ApplicationStatus, [ApplicationRecord])] {
        let grouped = Dictionary(grouping: applications, by: \.status)
        return ApplicationStatus.allCases.compactMap { status in
            guard let items = grouped[status], items.isNotEmpty else { return nil }
            return (status, items.sorted { $0.targetDeadline < $1.targetDeadline })
        }
    }
}
