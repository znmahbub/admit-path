import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let viewModel = SettingsViewModel(profile: appState.profile, notifications: appState.demoState.notifications)

        AppCanvas {
            HeroCard(
                eyebrow: "Account",
                title: viewModel.demoIdentity,
                subtitle: "Profile, budgets, family funding, trust signals, sync state, and staff access all live here."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: viewModel.intakeSummary, systemImage: "calendar", tint: .white)
                    SummaryPill(title: viewModel.focusSummary, systemImage: "graduationcap.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("Account")
                DetailRow(label: "Mode", value: appState.sessionRole.rawValue)
                DetailRow(label: "Identity", value: appState.accountDisplayName)
                Text(appState.accountSubtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
                Text(appState.syncStatus.summary)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)

                if appState.isSignedIn {
                    Button("Sign out of Google") {
                        Task {
                            await appState.signOut()
                        }
                    }
                    .buttonStyle(.bordered)

                    if appState.showsDemoControls {
                        Button("Replace cloud workspace with guest cache", role: .destructive) {
                            appState.replaceCloudStateWithGuestCache()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button("Continue with Google") {
                        Task {
                            await appState.signInWithGoogle()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                }

                if appState.canToggleAdminPreview {
                    Toggle(
                        "Admin preview",
                        isOn: Binding(
                            get: { appState.isAdminPreviewEnabled },
                            set: { appState.setAdminPreviewEnabled($0) }
                        )
                    )
                }
            }

            if appState.hasStaffAccess {
                SurfaceCard {
                    SectionTitle("Staff tools")
                    NavigationLink {
                        AdminOperationsView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open moderation and catalog queue")
                                    .font(.headline)
                                Text("Review reports, verification requests, and catalog freshness from inside the app.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.subtleText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.subtleText)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            SurfaceCard {
                SectionTitle("Profile")
                NavigationLink {
                    ProfileEditorView(initialProfile: appState.profile ?? .empty)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Edit student profile")
                                .font(.headline)
                            Text("Update academics, activities, budgets, funding plan, testing, and destination preferences.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtleText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.subtleText)
                    }
                }
                .buttonStyle(.plain)
                DetailRow(label: "Completeness", value: "\(appState.profile?.completenessScore ?? 0)%")
            }

            SurfaceCard {
                SectionTitle("Community trust model")
                DetailRow(label: "Bookmarked posts", value: "\(appState.bookmarkedPosts.count)")
                DetailRow(label: "Reports filed", value: "\(appState.demoState.reports.count)")
                Text("Open discussion is allowed, but verified admits, students, and alumni are ranked ahead of unverified advice.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
            }

            SurfaceCard {
                SectionTitle("Notifications")
                Toggle("Upcoming deadlines", isOn: Binding(
                    get: { appState.demoState.notifications.deadlineReminders },
                    set: {
                        var preferences = appState.demoState.notifications
                        preferences.deadlineReminders = $0
                        appState.updateNotificationPreferences(preferences)
                    }
                ))
                Toggle("Daily task reminders", isOn: Binding(
                    get: { appState.demoState.notifications.dailyTaskReminders },
                    set: {
                        var preferences = appState.demoState.notifications
                        preferences.dailyTaskReminders = $0
                        appState.updateNotificationPreferences(preferences)
                    }
                ))
                Toggle("Scholarship reminders", isOn: Binding(
                    get: { appState.demoState.notifications.scholarshipReminders },
                    set: {
                        var preferences = appState.demoState.notifications
                        preferences.scholarshipReminders = $0
                        appState.updateNotificationPreferences(preferences)
                    }
                ))
                Toggle("Weekly progress summary", isOn: Binding(
                    get: { appState.demoState.notifications.weeklyProgressSummary },
                    set: {
                        var preferences = appState.demoState.notifications
                        preferences.weeklyProgressSummary = $0
                        appState.updateNotificationPreferences(preferences)
                    }
                ))
            }

            if appState.showsDemoControls {
                SurfaceCard {
                    SectionTitle("Demo data")
                    Button("Load sample data") {
                        appState.loadSampleData()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)

                    Button(appState.isSignedIn ? "Reset current workspace" : "Reset all local data", role: .destructive) {
                        appState.resetAllData()
                    }
                    .buttonStyle(.bordered)
                }
            }

            SurfaceCard {
                SectionTitle("About this build")
                Text(AppConstants.aboutCopy)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
                Text("Catalog: \(appState.catalogFreshnessSummary)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
                Text("Supabase config: \(appState.environment.appConfig.isConfigured ? "present" : "placeholder")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
                Text("Stored locally at: \(appState.environment.stateStore.storageURL.path)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtleText)
            }
        }
        .navigationTitle("Account")
    }
}
