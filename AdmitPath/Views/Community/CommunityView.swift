import SwiftUI

private enum CommunitySurface: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case groups = "Groups"
    case saved = "Saved"
    case profile = "Profile"

    var id: String { rawValue }
}

struct CommunityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedSurface: CommunitySurface = .forYou
    @State private var showComposer = false
    @State private var showArtifactComposer = false
    @State private var showVerificationSheet = false

    var body: some View {
        AppCanvas {
            HeroCard(
                eyebrow: "Community",
                title: "A social feed and groups product built around real admissions decisions",
                subtitle: "Open posting stays allowed, but trust badges, relevance ranking, and program-linked context keep the signal usable."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "\(appState.communityFeed.count) feed posts", systemImage: "text.bubble.fill", tint: .white)
                    SummaryPill(title: "\(appState.communityGroups.count) recommended groups", systemImage: "person.3.sequence.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("Community surface")
                Picker("Community surface", selection: $selectedSurface) {
                    ForEach(CommunitySurface.allCases) { surface in
                        Text(surface.rawValue).tag(surface)
                    }
                }
                .pickerStyle(.segmented)

                Text("For You is ranked by profile relevance, trust, engagement, and freshness. Groups organize the social graph by destination, major, intake, and funding.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.subtleText)
            }

            SurfaceCard {
                SectionTitle("Contribute")
                Text("Ask a question, share an experience, or publish a trusted artifact. Open posting drives activity; moderation and trust badges keep it usable.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
                HStack(spacing: 10) {
                    Button("Create post") {
                        showComposer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)

                    Button("Share artifact") {
                        showArtifactComposer = true
                    }
                    .buttonStyle(.bordered)

                    if appState.isSignedIn && (appState.remoteUserProfile?.verificationStatus ?? .unverified) == .unverified {
                        Button("Get verified") {
                            showVerificationSheet = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            switch selectedSurface {
            case .forYou:
                forYouSection
            case .groups:
                groupsSection
            case .saved:
                savedSection
            case .profile:
                profileSection
            }
        }
        .navigationTitle("Community")
        .sheet(isPresented: $showComposer) {
            CommunityComposerSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showArtifactComposer) {
            ArtifactComposerSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showVerificationSheet) {
            VerificationRequestSheet()
                .environmentObject(appState)
        }
    }

    private var forYouSection: some View {
        Group {
            if appState.communityFeed.isEmpty {
                EmptyStateCard(
                    title: "No community posts yet",
                    message: "Create the first relevant thread tied to your destination, major, or funding questions.",
                    buttonTitle: "Create post"
                ) {
                    showComposer = true
                }
            } else {
                SurfaceCard {
                    SectionTitle("For You", subtitle: "Ranked for your profile, shortlist, and trust preferences.")
                    ForEach(appState.communityFeed) { item in
                        NavigationLink {
                            CommunityPostDetailView(post: item.post)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
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
                                    .lineLimit(4)
                                HStack(spacing: 8) {
                                    SummaryPill(title: item.post.country, systemImage: "globe", tint: AppTheme.teal)
                                    SummaryPill(title: item.post.degreeLevel.rawValue, systemImage: "graduationcap", tint: AppTheme.primary)
                                    SummaryPill(title: "Score \(item.ranking.totalScore)", systemImage: "waveform.path.ecg", tint: AppTheme.success)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        HStack {
                            Button(appState.savedFeedPosts.contains(where: { $0.id == item.id }) ? "Saved" : "Save") {
                                appState.toggleBookmarkedPost(item.post.id)
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Text("Relevance \(item.ranking.relevanceScore) • Trust \(item.ranking.trustScore)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtleText)
                        }
                    }
                }
            }
        }
    }

    private var groupsSection: some View {
        Group {
            if appState.communityGroups.isEmpty {
                EmptyStateCard(
                    title: "No recommended groups yet",
                    message: "Complete your profile to unlock destination, major, intake, and funding groups.",
                    buttonTitle: "Open Account"
                ) {}
            } else {
                SurfaceCard {
                    SectionTitle("Recommended groups")
                    ForEach(appState.communityGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(group.title)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(title: group.kind.rawValue, color: AppTheme.primary)
                            }
                            Text(group.subtitle)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                            HStack(spacing: 8) {
                                SummaryPill(title: "\(group.memberCount) members", systemImage: "person.2.fill", tint: AppTheme.teal)
                                SummaryPill(title: "\(group.postCount) posts", systemImage: "text.bubble.fill", tint: AppTheme.gold)
                            }
                        }
                    }
                }
            }
        }
    }

    private var savedSection: some View {
        Group {
            if appState.savedFeedPosts.isEmpty {
                EmptyStateCard(
                    title: "No saved posts yet",
                    message: "Save the best community advice so it stays close to your application workflow.",
                    buttonTitle: "Browse feed"
                ) {
                    selectedSurface = .forYou
                }
            } else {
                SurfaceCard {
                    SectionTitle("Saved posts")
                    ForEach(appState.savedFeedPosts) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.post.title)
                                .font(.headline)
                            Text(item.post.body)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                                .lineLimit(4)
                            Button("Remove from saved") {
                                appState.toggleBookmarkedPost(item.post.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var profileSection: some View {
        SurfaceCard {
            SectionTitle("Community profile")
            DetailRow(label: "Display name", value: appState.accountDisplayName)
            DetailRow(label: "Mode", value: appState.sessionRole.rawValue.capitalized)
            DetailRow(label: "Verification", value: appState.remoteUserProfile?.verificationStatus.rawValue ?? "Unverified")
            DetailRow(label: "Your posts", value: "\(appState.demoState.userPosts.count)")
            DetailRow(label: "Your replies", value: "\(appState.demoState.userReplies.count)")
            DetailRow(label: "Your artifacts", value: "\(appState.demoState.userArtifacts.count)")
            Text("Profile-aware ranking means your destination and major choices shape which posts and groups rise to the top.")
                .font(.footnote)
                .foregroundStyle(AppTheme.subtleText)
        }
    }
}

private struct CommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var title = ""
    @State private var bodyText = ""
    @State private var country = AppConstants.supportedCountries.first ?? "United States"
    @State private var subjectArea = AppConstants.supportedSubjects.first ?? "Computer Science"
    @State private var degreeLevel: DegreeLevel = .undergrad

    var body: some View {
        NavigationStack {
            Form {
                Section("Post") {
                    TextField("Title", text: $title)
                    TextField("What exactly do you want help with?", text: $bodyText, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                }

                Section("Context") {
                    Picker("Country", selection: $country) {
                        ForEach(AppConstants.supportedCountries, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Subject", selection: $subjectArea) {
                        ForEach(AppConstants.supportedSubjects, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Degree", selection: $degreeLevel) {
                        ForEach(DegreeLevel.allCases) { degree in
                            Text(degree.rawValue).tag(degree)
                        }
                    }
                }
            }
            .navigationTitle("Create Post")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        appState.submitCommunityPost(
                            title: title,
                            body: bodyText,
                            kind: .question,
                            country: country,
                            subjectArea: subjectArea,
                            degreeLevel: degreeLevel,
                            tags: ["community", "feed"]
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ArtifactComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var title = ""
    @State private var summary = ""
    @State private var highlights = ""
    @State private var country = AppConstants.supportedCountries.first ?? "United States"
    @State private var subjectArea = AppConstants.supportedSubjects.first ?? "Computer Science"
    @State private var degreeLevel: DegreeLevel = .undergrad
    @State private var kind: PeerArtifactKind = .sopSample

    var body: some View {
        NavigationStack {
            Form {
                Section("Artifact") {
                    TextField("Title", text: $title)
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                    Picker("Type", selection: $kind) {
                        ForEach(PeerArtifactKind.allCases) { artifactKind in
                            Text(artifactKind.rawValue).tag(artifactKind)
                        }
                    }
                }

                Section("Context") {
                    Picker("Country", selection: $country) {
                        ForEach(AppConstants.supportedCountries, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Subject", selection: $subjectArea) {
                        ForEach(AppConstants.supportedSubjects, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    Picker("Degree", selection: $degreeLevel) {
                        ForEach(DegreeLevel.allCases) { degree in
                            Text(degree.rawValue).tag(degree)
                        }
                    }
                    TextField("Highlights (one per line)", text: $highlights, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
            }
            .navigationTitle("Share Artifact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let bullets = highlights
                            .split(whereSeparator: \.isNewline)
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        appState.submitArtifact(
                            title: title,
                            summary: summary,
                            kind: kind,
                            country: country,
                            subjectArea: subjectArea,
                            degreeLevel: degreeLevel,
                            bulletHighlights: bullets
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct VerificationRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Verification request") {
                    TextField("Tell staff what you want verified", text: $note, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                }
            }
            .navigationTitle("Get Verified")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        appState.requestVerification(note: note)
                        dismiss()
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
