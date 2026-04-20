import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let viewModel = HomeViewModel(snapshot: appState.homeSnapshot, displayName: appState.profile?.displayName ?? "there")

        AppCanvas {
            HeroCard(
                eyebrow: "Today",
                title: viewModel.greeting,
                subtitle: "Drive the next highest-value action across discovery, applications, funding, and community instead of guessing what matters next."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(
                        title: "\(viewModel.snapshot.readinessScore.overall)% ready",
                        systemImage: "speedometer",
                        tint: .white
                    )
                    SummaryPill(
                        title: "\(viewModel.snapshot.pendingTaskCount) open blockers",
                        systemImage: "checklist.unchecked",
                        tint: .white
                    )
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                MetricTile(
                    title: "Applications",
                    value: "\(viewModel.snapshot.applicationsInProgress)",
                    subtitle: "active plans",
                    color: AppTheme.primary
                )
                MetricTile(
                    title: "Discover",
                    value: "\(viewModel.snapshot.savedProgramsCount)",
                    subtitle: "saved programs",
                    color: AppTheme.teal
                )
                MetricTile(
                    title: "Funding",
                    value: "\(viewModel.snapshot.fundingScenarios.count)",
                    subtitle: "live scenarios",
                    color: AppTheme.gold
                )
                MetricTile(
                    title: "Community",
                    value: "\(viewModel.snapshot.featuredFeed.count)",
                    subtitle: "high-signal posts",
                    color: AppTheme.success
                )
            }

            SurfaceCard {
                SectionTitle("Next action", subtitle: viewModel.snapshot.continueSubtitle)
                Text(viewModel.urgencySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
                Button(viewModel.snapshot.continueTitle) {
                    appState.openContinueFlow()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }

            SurfaceCard {
                SectionTitle("Decision readiness")
                DetailRow(label: "Profile", value: "\(viewModel.snapshot.readinessScore.profile)%")
                DetailRow(label: "Testing", value: "\(viewModel.snapshot.readinessScore.testing)%")
                DetailRow(label: "Essays", value: "\(viewModel.snapshot.readinessScore.essays)%")
                DetailRow(label: "Applications", value: "\(viewModel.snapshot.readinessScore.applications)%")
                DetailRow(label: "Funding", value: "\(viewModel.snapshot.readinessScore.funding)%")
                if viewModel.snapshot.readinessScore.blockers.isNotEmpty {
                    ForEach(viewModel.snapshot.readinessScore.blockers, id: \.self) { blocker in
                        Text("• \(blocker)")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.subtleText)
                    }
                }
            }

            SurfaceCard {
                SectionTitle("Workspace health")
                DetailRow(label: "Account", value: appState.sessionRole.rawValue.capitalized)
                DetailRow(label: "Cloud sync", value: appState.syncStatus.summary)
                DetailRow(label: "Catalog", value: appState.catalogFreshnessSummary)
                if let lastSyncedAt = appState.lastSyncedAt {
                    DetailRow(label: "Last synced", value: formatDate(lastSyncedAt))
                }
                if !appState.syncStatus.canWriteCloud {
                    Button("Retry cloud sync") {
                        Task {
                            await appState.retryCloudSync()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.snapshot.fundingScenarios.isNotEmpty {
                SurfaceCard {
                    SectionTitle("Funding watch")
                    ForEach(viewModel.snapshot.fundingScenarios.prefix(3)) { scenario in
                        VStack(alignment: .leading, spacing: 6) {
                            DetailRow(label: "Net cost", value: formatCurrency(scenario.netCostAfterScholarshipsUSD))
                            DetailRow(label: "Remaining gap", value: scenario.remainingGapUSD == 0 ? "Covered" : formatCurrency(scenario.remainingGapUSD))
                            Text(scenario.netCostSummary)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                        }
                    }
                    Button("Open funding planning") {
                        appState.openFunding()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.snapshot.topMatches.isNotEmpty {
                SurfaceCard {
                    SectionTitle("Discover next", subtitle: "Shortlist options that still look realistic after funding context.")
                    ForEach(Array(viewModel.snapshot.topMatches.enumerated()), id: \.element.id) { index, match in
                        Button {
                            appState.openProgram(match.program.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(match.program.name)
                                        .font(.headline)
                                    Spacer()
                                    FitBadge(band: match.fitBand)
                                }
                                Text("\(match.program.universityName) • \(match.country)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text(match.explanation)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.subtleText)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("today-top-match-\(index)")
                    }
                }
            }

            if viewModel.snapshot.featuredFeed.isNotEmpty {
                SurfaceCard {
                    SectionTitle("Community signal", subtitle: "Posts worth acting on now, not generic noise.")
                    ForEach(viewModel.snapshot.featuredFeed) { item in
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
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                }
            }

            SurfaceCard {
                SectionTitle("Essays and requirements")
                DetailRow(label: "Checklist readiness", value: "\(appState.documentsChecklist().filter(\.isReady).count)/\(appState.documentsChecklist().count)")
                DetailRow(label: "Essay workspace", value: appState.demoState.sopProjects.first?.title ?? "No draft started")
                Button("Open essay workspace") {
                    appState.openDocuments(programID: appState.demoState.sopProjects.first?.programID)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
        }
        .navigationTitle("Today")
    }
}
