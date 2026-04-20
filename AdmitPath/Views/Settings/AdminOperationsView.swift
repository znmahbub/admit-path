import SwiftUI

struct AdminOperationsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        AppCanvas {
            HeroCard(
                eyebrow: "Staff operations",
                title: "Moderation, verification, and catalog freshness",
                subtitle: "Use the lightweight in-app queue for the most common beta operations. Supabase Studio remains the fallback for raw fixes."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "\(appState.adminDashboard.reports.count) reports", systemImage: "flag.fill", tint: .white)
                    SummaryPill(title: "\(appState.adminDashboard.verificationRequests.count) verification requests", systemImage: "checkmark.shield.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("Workspace")
                DetailRow(label: "Account mode", value: appState.sessionRole.rawValue)
                DetailRow(label: "Cloud sync", value: appState.syncStatus.summary)
                if appState.isLoadingAdminDashboard {
                    ProgressView("Refreshing staff dashboard")
                        .tint(AppTheme.primary)
                }
                Button("Refresh queue") {
                    Task {
                        await appState.refreshAdminDashboard()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }

            SurfaceCard {
                SectionTitle("Reports")
                if appState.adminDashboard.reports.isEmpty {
                    Text("No pending reports right now.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                } else {
                    ForEach(appState.adminDashboard.reports) { report in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(report.postID)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(title: report.status.rawValue, color: report.status.tint)
                            }
                            Text(report.reason)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                            HStack(spacing: 10) {
                                Button("Keep Clear") {
                                    appState.updateReportStatus(report.id, status: .clear)
                                }
                                .buttonStyle(.bordered)

                                Button("Limit Content") {
                                    appState.updateReportStatus(report.id, status: .limited)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.warning)
                            }
                        }
                    }
                }
            }

            SurfaceCard {
                SectionTitle("Verification requests")
                if appState.adminDashboard.verificationRequests.isEmpty {
                    Text("No verification requests are waiting.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                } else {
                    ForEach(appState.adminDashboard.verificationRequests) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(request.userEmail ?? request.userID)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(title: request.status.rawValue, color: request.status.tint)
                            }
                            Text(request.note)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                            HStack(spacing: 10) {
                                Button("Approve student") {
                                    appState.updateVerificationRequest(
                                        requestID: request.id,
                                        userID: request.userID,
                                        verificationStatus: .verifiedStudent
                                    )
                                }
                                .buttonStyle(.bordered)

                                Button("Approve admit") {
                                    appState.updateVerificationRequest(
                                        requestID: request.id,
                                        userID: request.userID,
                                        verificationStatus: .verifiedAdmit
                                    )
                                }
                                .buttonStyle(.bordered)

                                Button("Approve alumni") {
                                    appState.updateVerificationRequest(
                                        requestID: request.id,
                                        userID: request.userID,
                                        verificationStatus: .verifiedAlumni
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.primary)
                            }
                        }
                    }
                }
            }

            SurfaceCard {
                SectionTitle("Catalog freshness")
                if appState.adminDashboard.stalePrograms.isEmpty {
                    Text("Catalog freshness looks healthy.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                } else {
                    ForEach(appState.adminDashboard.stalePrograms) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.program.name)
                                        .font(.headline)
                                    Text("\(item.program.universityName) • \(item.country)")
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.subtleText)
                                }
                                Spacer()
                                StatusBadge(title: item.program.dataFreshness, color: AppTheme.gold)
                            }
                            DetailRow(label: "Last updated", value: formatDate(item.program.lastUpdatedAt))
                            Button("Mark refreshed today") {
                                appState.markProgramFreshness(item.program.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle("Staff Tools")
        .task {
            await appState.refreshAdminDashboard()
        }
    }
}
