import SwiftUI

struct ProgramCompareView: View {
    let matches: [ProgramMatch]

    var body: some View {
        AppCanvas {
            HeroCard(
                eyebrow: "Compare",
                title: "Shortlist side by side",
                subtitle: "Use this view to compare cost, deadlines, requirements, and fit rather than relying on memory."
            ) {
                SummaryPill(title: "\(matches.count) programs", systemImage: "rectangle.split.3x1", tint: .white)
            }

            ForEach(matches) { match in
                SurfaceCard {
                    HStack {
                        Text(match.program.name)
                            .font(.headline)
                        Spacer()
                        FitBadge(band: match.fitBand)
                    }
                    Text("\(match.program.universityName) • \(match.country)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    DetailRow(label: "Degree", value: match.program.degreeLevel.rawValue)
                    DetailRow(label: "Tuition", value: formatCurrency(match.program.tuitionUSD))
                    DetailRow(label: "Total cost", value: formatCurrency(match.program.totalCostOfAttendanceUSD))
                    DetailRow(label: "Duration", value: "\(match.program.durationMonths) months")
                    DetailRow(label: "Next deadline", value: match.nextDeadline.map { formatDate($0.applicationDeadline) } ?? "Not listed")
                    DetailRow(label: "SOP required", value: (match.requirement?.sopRequired ?? false) ? "Yes" : "No")
                    DetailRow(label: "LOR count", value: "\(match.requirement?.lorCount ?? 0)")
                    DetailRow(label: "Scholarships", value: "\(match.scholarshipCount)")
                }
            }
        }
        .navigationTitle("Compare")
    }
}
