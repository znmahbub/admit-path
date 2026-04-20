import SwiftUI

struct AdaptiveRootContainer: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            AppBackgroundView()

            if appState.launchState.isBlocking {
                LaunchRecoveryView(state: appState.launchState, retry: appState.retryBootstrap)
            } else if appState.requiresAuthenticationGate {
                SignInGateView()
                    .environmentObject(appState)
            } else if !appState.hasCompletedOnboarding {
                OnboardingContainerView(appState: appState)
            } else if prefersSidebarLayout {
                sidebarShell
            } else {
                compactShell
            }

            if case .warning = appState.launchState {
                AppNoticeBanner(
                    state: appState.launchState,
                    dismiss: appState.dismissLaunchNotice,
                    retry: appState.retryBootstrap
                )
            }

            VStack {
                SyncStatusBanner(status: appState.syncStatus) {
                    Task {
                        await appState.retryCloudSync()
                    }
                }
                Spacer()
            }
        }
        .tint(AppTheme.primary)
        .sheet(item: $appState.authPrompt) { prompt in
            AuthPromptSheet(prompt: prompt)
                .environmentObject(appState)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(appState)
            }
        }
    }

    private var compactShell: some View {
        TabView(selection: $appState.selectedTab) {
            tabStack(for: .today)
                .tabItem { Label(AppTab.today.rawValue, systemImage: AppTab.today.systemImage) }
                .tag(AppTab.today)

            tabStack(for: .discover)
                .tabItem { Label(AppTab.discover.rawValue, systemImage: AppTab.discover.systemImage) }
                .tag(AppTab.discover)

            tabStack(for: .community)
                .tabItem { Label(AppTab.community.rawValue, systemImage: AppTab.community.systemImage) }
                .tag(AppTab.community)

            tabStack(for: .apply)
                .tabItem { Label(AppTab.apply.rawValue, systemImage: AppTab.apply.systemImage) }
                .tag(AppTab.apply)

            tabStack(for: .funding)
                .tabItem { Label(AppTab.funding.rawValue, systemImage: AppTab.funding.systemImage) }
                .tag(AppTab.funding)
        }
    }

    private var sidebarShell: some View {
        NavigationSplitView {
            List(
                AppTab.allCases,
                selection: Binding(
                    get: { Optional(appState.selectedTab) },
                    set: { selection in
                        if let selection {
                            appState.selectedTab = selection
                        }
                    }
                )
            ) { tab in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.rawValue)
                        Text(tab.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtleText)
                    }
                } icon: {
                    Image(systemName: tab.systemImage)
                }
                .tag(tab)
            }
            .navigationTitle("AdmitPath")
            .listStyle(.sidebar)
        } detail: {
            tabStack(for: appState.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func tabStack(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            NavigationStack {
                HomeDashboardView()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            accountButton
                        }
                    }
                    .navigationDestination(item: $appState.routedProgram) { route in
                        if let match = appState.match(for: route.id) {
                            ProgramDetailView(match: match)
                        } else {
                            ContentUnavailableView("Program not found", systemImage: "magnifyingglass")
                        }
                    }
                    .navigationDestination(item: $appState.routedApplication) { route in
                        ApplicationDetailView(applicationID: route.id)
                    }
                    .navigationDestination(item: $appState.routedSOPProject) { route in
                        SOPBuilderView(
                            initialProgramID: route.programID,
                            existingProject: appState.demoState.sopProjects.first(where: { $0.id == route.id })
                        )
                    }
            }
        case .discover:
            NavigationStack {
                MatchesListView()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            accountButton
                        }
                    }
                    .navigationDestination(item: $appState.routedProgram) { route in
                        if let match = appState.match(for: route.id) {
                            ProgramDetailView(match: match)
                        } else {
                            ContentUnavailableView("Program not found", systemImage: "magnifyingglass")
                        }
                    }
            }
        case .apply:
            NavigationStack {
                ApplicationsListView()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            accountButton
                        }
                    }
                    .navigationDestination(item: $appState.routedApplication) { route in
                        ApplicationDetailView(applicationID: route.id)
                    }
                    .navigationDestination(item: $appState.routedSOPProject) { route in
                        SOPBuilderView(
                            initialProgramID: route.programID,
                            existingProject: appState.demoState.sopProjects.first(where: { $0.id == route.id })
                        )
                    }
            }
        case .community:
            NavigationStack {
                CommunityView()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            accountButton
                        }
                    }
            }
        case .funding:
            NavigationStack {
                FundingView()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            accountButton
                        }
                    }
            }
        }
    }

    private var prefersSidebarLayout: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    private var accountButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("Open account")
    }
}

private struct SignInGateView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 18) {
            HeroCard(
                eyebrow: "Private beta",
                title: "Sign in to open your admissions workspace",
                subtitle: "Google sign-in unlocks your saved shortlist, applications, deadlines, SOP drafts, and peer contributions across devices."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "Google auth", systemImage: "lock.shield.fill", tint: .white)
                    SummaryPill(title: "Cloud sync", systemImage: "arrow.triangle.2.circlepath.circle.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("Why the beta starts with sign-in")
                TimelineRow(
                    title: "Keep one real workspace",
                    subtitle: "Your shortlist, applications, SOP drafts, and community actions stay attached to one account.",
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: AppTheme.primary,
                    trailing: nil
                )
                TimelineRow(
                    title: "Protect trusted peer content",
                    subtitle: "Verification, moderation, and reporting only work properly when activity is tied to a real account.",
                    systemImage: "checkmark.shield.fill",
                    tint: AppTheme.teal,
                    trailing: nil
                )
                TimelineRow(
                    title: "Resume on another device",
                    subtitle: "The TestFlight MVP is meant to behave like a real product, not a one-device demo.",
                    systemImage: "iphone.gen3.badge.play",
                    tint: AppTheme.gold,
                    trailing: nil
                )
            }

            Button {
                Task {
                    await appState.signInWithGoogle()
                }
            } label: {
                HStack {
                    Spacer()
                    if appState.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Continue with Google")
                            .font(.headline)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
            .disabled(appState.isAuthenticating)

            if appState.canToggleAdminPreview {
                Button("Open beta admin preview instead") {
                    appState.setAdminPreviewEnabled(true)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(maxWidth: 620)
    }
}

private struct AuthPromptSheet: View {
    @EnvironmentObject private var appState: AppState

    let prompt: AuthPrompt

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                HeroCard(
                    eyebrow: "Google sign-in",
                    title: prompt.title,
                    subtitle: prompt.message
                ) {
                    SummaryPill(
                        title: appState.sessionRole.rawValue.capitalized,
                        systemImage: "person.crop.circle.badge.checkmark",
                        tint: .white
                    )
                }

                SurfaceCard {
                    SectionTitle("What changes after sign-in")
                    Text("Saved programs, comparisons, applications, SOP projects, bookmarks, and reports sync across devices once you use Google.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                }

                Button {
                    Task {
                        await appState.signInWithGoogle()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if appState.isAuthenticating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Continue with Google")
                                .font(.headline)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .disabled(appState.isAuthenticating)

                if appState.canToggleAdminPreview {
                    Button("Open beta admin preview instead") {
                        appState.setAdminPreviewEnabled(true)
                        appState.dismissAuthPrompt()
                    }
                    .buttonStyle(.bordered)
                }

                Text(appState.syncStatus.summary)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        appState.dismissAuthPrompt()
                    }
                }
            }
        }
    }
}
