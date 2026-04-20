import SwiftUI

struct ApplicationsListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let viewModel = ApplicationsViewModel()
        let grouped = viewModel.groupedApplications(appState.applications)
        let plannerCount = appState.demoState.plannerItems.filter { !$0.isCompleted }.count

        AppCanvas {
            HeroCard(
                eyebrow: "Apply",
                title: "Turn a shortlist into deadlines, essays, recommenders, and submission readiness",
                subtitle: "This is the daily-use loop: requirements, milestones, funding, essay work, and school-specific guidance."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "\(appState.applications.count) applications", systemImage: "tray.full.fill", tint: .white)
                    SummaryPill(title: "\(plannerCount) open milestones", systemImage: "calendar.badge.clock", tint: .white)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                MetricTile(
                    title: "In progress",
                    value: "\(appState.applications.count)",
                    subtitle: "tracked applications",
                    color: AppTheme.primary
                )
                MetricTile(
                    title: "Tracked funding",
                    value: "\(appState.trackedScholarships.count)",
                    subtitle: "scholarships in play",
                    color: AppTheme.gold
                )
            }

            SurfaceCard {
                SectionTitle("Essay workspace")
                Text("The old standalone documents flow now lives inside Apply where personal statements, supplements, and requirement readiness are most useful.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
                Button("Open essay workspace") {
                    appState.openDocuments(programID: appState.demoState.sopProjects.first?.programID)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }

            if grouped.isEmpty {
                EmptyStateCard(
                    title: "No applications yet",
                    message: "Save a program from Discover, then convert it into an application to unlock milestones and generated tasks.",
                    buttonTitle: "Browse Discover"
                ) {
                    appState.selectedTab = .discover
                }
            } else {
                ForEach(grouped, id: \.0) { status, applications in
                    SurfaceCard {
                        SectionTitle(status.rawValue, subtitle: "\(applications.count) application\(applications.count == 1 ? "" : "s") in this stage")
                        ForEach(applications) { application in
                            Button {
                                appState.openApplication(application.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(application.programName)
                                            .font(.headline)
                                        Spacer()
                                        StatusBadge(title: application.status.rawValue, color: application.status.tint)
                                    }
                                    Text("\(application.universityName) • \(application.country)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                    HStack(spacing: 8) {
                                        SummaryPill(title: appState.applicationSystem(for: application.country).rawValue, systemImage: "square.stack.3d.up.fill", tint: AppTheme.teal)
                                        SummaryPill(title: "\(application.completionPercent)% complete", systemImage: "chart.pie.fill", tint: AppTheme.primary)
                                        SummaryPill(title: formatDate(application.targetDeadline), systemImage: "calendar", tint: AppTheme.warning)
                                    }
                                    ProgressView(value: Double(application.completionPercent), total: 100)
                                        .tint(AppTheme.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Apply")
    }
}
