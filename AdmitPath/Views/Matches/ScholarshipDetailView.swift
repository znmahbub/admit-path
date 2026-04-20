import SwiftUI

struct ScholarshipDetailView: View {
    @EnvironmentObject private var appState: AppState

    let match: ScholarshipMatch

    var body: some View {
        AppCanvas {
            HeroCard(
                eyebrow: "Scholarship detail",
                title: match.scholarship.name,
                subtitle: "\(match.scholarship.sponsor) • deadline \(formatDate(match.scholarship.deadline))"
            ) {
                StatusBadge(title: match.level.rawValue, color: match.level.tint)
            }

            SurfaceCard {
                SectionTitle("Coverage")
                Text(match.scholarship.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                HStack(spacing: 8) {
                    SummaryPill(title: match.scholarship.coverageType.rawValue, systemImage: "banknote.fill", tint: AppTheme.primary)
                    if let amount = match.scholarship.maxAmountUSD {
                        SummaryPill(title: formatCurrency(amount), systemImage: "wallet.pass.fill", tint: AppTheme.teal)
                    }
                }
                DetailRow(label: "Projected remaining tuition gap", value: match.projectedGapUSD == 0 ? "Covered relative to current tuition budget" : formatCurrency(match.projectedGapUSD))
            }

            SurfaceCard {
                SectionTitle("Eligibility")
                DetailRow(label: "Destination countries", value: match.scholarship.destinationCountries.joined(separator: ", "))
                DetailRow(label: "Subjects", value: match.scholarship.eligibleSubjects.joined(separator: ", "))
                DetailRow(label: "Degree levels", value: match.scholarship.eligibleDegreeLevels.map(\.rawValue).joined(separator: ", "))
                DetailRow(label: "Minimum GPA", value: match.scholarship.minGPAValue.map { formatDecimal($0, digits: 1) } ?? "Not specified")
                if let secondary = match.scholarship.minSecondaryPercent {
                    DetailRow(label: "Minimum secondary result", value: "\(formatDecimal(secondary, digits: 1))%")
                }
            }

            SurfaceCard {
                SectionTitle("Why it fits")
                Text(match.reason)
                    .font(.subheadline)
                if match.scholarship.essayPromptHint.isNotEmpty {
                    DetailRow(label: "Essay angle", value: match.scholarship.essayPromptHint)
                }
            }

            if let url = URL(string: match.scholarship.officialURL) {
                SurfaceCard {
                    Link(destination: url) {
                        Label("Open official scholarship page", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("Scholarship Detail")
        .appInlineNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            Button(appState.trackedScholarships.contains(where: { $0.id == match.scholarship.id }) ? "Tracked" : "Track scholarship") {
                appState.toggleTrackedScholarship(match.scholarship.id)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }
}
