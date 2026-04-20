import SwiftUI

struct ScholarshipListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppCanvas {
            HeroCard(
                eyebrow: "Funding",
                title: "Scholarships ranked against the current applicant profile",
                subtitle: "These results are rule-based, country-aware, and explicit about why a scholarship looks viable."
            ) {
                SummaryPill(
                    title: "\(appState.scholarshipMatches.filter { $0.level != .unlikely }.count) plausible",
                    systemImage: "graduationcap.fill",
                    tint: .white
                )
            }

            if appState.scholarshipMatches.isEmpty {
                EmptyStateCard(
                    title: "No scholarships yet",
                    message: "Finish the student profile to unlock eligibility ranking."
                )
            } else {
                ForEach(appState.scholarshipMatches) { match in
                    NavigationLink {
                        ScholarshipDetailView(match: match)
                    } label: {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(match.scholarship.name)
                                        .font(.headline)
                                    Spacer()
                                    StatusBadge(title: match.level.rawValue, color: match.level.tint)
                                }
                                Text(match.scholarship.sponsor)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                                HStack(spacing: 8) {
                                    SummaryPill(title: match.scholarship.coverageType.rawValue, systemImage: "banknote.fill", tint: AppTheme.primary)
                                    SummaryPill(title: formatDate(match.scholarship.deadline), systemImage: "calendar", tint: AppTheme.warning)
                                }
                                Text(match.reason)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.subtleText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Scholarships")
    }
}
