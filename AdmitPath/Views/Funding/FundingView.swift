import SwiftUI

struct FundingView: View {
    @EnvironmentObject private var appState: AppState

    private var fundingPosts: [FeedPost] {
        appState.communityFeed.filter { $0.post.kind == .scholarshipAdvice }.prefix(4).map { $0 }
    }

    var body: some View {
        let familyPlan = appState.profile?.resolvedFamilyFundingPlan ?? .empty

        AppCanvas {
            HeroCard(
                eyebrow: "Bangladesh-first funding OS",
                title: "See what the shortlist really costs after scholarships and family support",
                subtitle: "Use affordability scenarios, scholarship context, and peer funding tips before you commit to a destination."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "\(appState.affordabilityScenarios.count) scenarios", systemImage: "banknote.fill", tint: .white)
                    SummaryPill(title: "\(appState.scholarshipMatches.filter { $0.level != .unlikely }.count) likely scholarships", systemImage: "graduationcap.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("Family funding plan")
                DetailRow(label: "Guardian contribution", value: formatCurrency(familyPlan.guardianContributionUSD))
                DetailRow(label: "Savings", value: formatCurrency(familyPlan.savingsUSD))
                DetailRow(label: "Monthly budget", value: formatCurrency(familyPlan.monthlyBudgetUSD))
                DetailRow(label: "Loan support", value: familyPlan.needsLoanSupport ? "Expected" : "Not assumed yet")
                Text("This summary is BDT-aware through your stored budget inputs and turns family support into comparable USD planning figures.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
            }

            if appState.affordabilityScenarios.isNotEmpty {
                SurfaceCard {
                    SectionTitle("Affordability scenarios", subtitle: "Net cost after scholarships, then the remaining family gap.")
                    ForEach(appState.affordabilityScenarios.prefix(5)) { scenario in
                        VStack(alignment: .leading, spacing: 8) {
                            if let match = appState.matches.first(where: { $0.program.id == scenario.id.replacingOccurrences(of: "affordability_", with: "") }) {
                                Button {
                                    appState.openProgram(match.program.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(match.program.name)
                                                .font(.headline)
                                            Spacer()
                                            FitBadge(band: match.fitBand)
                                        }
                                        Text("\(match.program.universityName) • \(scenario.country)")
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                            DetailRow(label: "Total cost", value: formatCurrency(scenario.totalCostUSD))
                            DetailRow(label: "Scholarships", value: formatCurrency(scenario.scholarshipSupportUSD))
                            DetailRow(label: "Net cost", value: formatCurrency(scenario.netCostAfterScholarshipsUSD))
                            DetailRow(label: "Family gap", value: scenario.remainingGapUSD == 0 ? "Covered" : formatCurrency(scenario.remainingGapUSD))
                            Text(scenario.netCostSummary)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                        }
                    }
                }
            } else {
                EmptyStateCard(
                    title: "No affordability scenarios yet",
                    message: "Complete the profile and shortlist to unlock funding planning.",
                    buttonTitle: "Open Discover"
                ) {
                    appState.selectedTab = .discover
                }
            }

            SurfaceCard {
                SectionTitle("Scholarship angles")
                if appState.scholarshipMatches.isEmpty {
                    Text("Add more profile detail to rank scholarships and estimate the net cost of your shortlist.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                } else {
                    ForEach(appState.scholarshipMatches.prefix(4)) { match in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(match.scholarship.name)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(title: match.level.rawValue, color: match.level.tint)
                            }
                            Text(match.reason)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                            if let amount = match.scholarship.maxAmountUSD {
                                SummaryPill(title: formatCurrency(amount), systemImage: "banknote", tint: AppTheme.primary)
                            }
                        }
                    }
                }
            }

            if fundingPosts.isNotEmpty {
                SurfaceCard {
                    SectionTitle("Funding community signals")
                    ForEach(fundingPosts) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.post.title)
                                    .font(.headline)
                                Spacer()
                                if let trustBadge = item.trustBadge {
                                    StatusBadge(title: trustBadge, color: AppTheme.gold)
                                }
                            }
                            Text(item.post.body)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                                .lineLimit(3)
                        }
                    }
                    Button("Open community") {
                        appState.selectedTab = .community
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Funding")
    }
}
