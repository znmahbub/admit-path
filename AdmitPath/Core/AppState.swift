import Combine
import Foundation

struct RoutedProgram: Hashable, Identifiable {
    let id: String
}

struct RoutedApplication: Hashable, Identifiable {
    let id: String
}

struct RoutedSOPProject: Hashable, Identifiable {
    let id: String
    let programID: String?
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published private(set) var launchState: AppLaunchState
    @Published private(set) var demoState: DemoState
    @Published private(set) var authState: AuthState
    @Published private(set) var syncStatus: SyncStatus
    @Published private(set) var remoteUserProfile: RemoteUserProfile?
    @Published private(set) var adminDashboard: AdminDashboardSnapshot = .empty
    @Published private(set) var isLoadingAdminDashboard = false
    @Published var authPrompt: AuthPrompt?
    @Published var routedProgram: RoutedProgram?
    @Published var routedApplication: RoutedApplication?
    @Published var routedSOPProject: RoutedSOPProject?

    private let bundle: Bundle
    private let fileManager: FileManager
    private let baseDirectory: URL?
    private var guestStateCache: DemoState
    private var hasStarted = false
    private var cloudSaveTask: Task<Void, Never>?

    private(set) var environment: AppEnvironment

    convenience init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        let result = AppEnvironment.bootstrap(
            bundle: bundle,
            fileManager: fileManager,
            baseDirectory: baseDirectory
        )
        self.init(
            environment: result.environment,
            initialState: result.initialState,
            launchState: result.launchState,
            bundle: bundle,
            fileManager: fileManager,
            baseDirectory: baseDirectory
        )
    }

    init(
        environment: AppEnvironment,
        initialState: DemoState? = nil,
        launchState: AppLaunchState = .ready,
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) {
        let initialWorkspace = initialState ?? environment.resetService.emptyState()
        let initialAuthState: AuthState = if environment.runtimeOptions.enableAdminPreviewOnLaunch && environment.appConfig.enableAdminPreview {
            .adminPreview
        } else {
            .guest
        }

        self.environment = environment
        self.demoState = initialWorkspace
        self.guestStateCache = initialWorkspace
        self.launchState = launchState
        self.authState = initialAuthState
        self.syncStatus = .localGuest
        self.bundle = bundle
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        refreshNotifications()
    }

    var profile: StudentProfile? {
        environment.profileRepository.profile(in: demoState)
    }

    var hasCompletedOnboarding: Bool {
        profile?.onboardingComplete == true
    }

    var isSignedIn: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }

    var isAuthenticating: Bool {
        if case .authenticating = authState {
            return true
        }
        return false
    }

    var isAdminPreviewEnabled: Bool {
        authState.isAdminPreview
    }

    var canToggleAdminPreview: Bool {
        environment.appConfig.enableAdminPreview && !isSignedIn
    }

    var showsDemoControls: Bool {
        environment.runtimeOptions.showsDemoControls || environment.appConfig.enableTestMockAuth
    }

    var requiresAuthenticationGate: Bool {
        environment.appConfig.productionRequiresSignIn
            && !environment.runtimeOptions.forceGuestMode
            && !environment.runtimeOptions.useMockAuthenticatedSession
            && !authState.isAdminPreview
            && !isSignedIn
    }

    var hasStaffAccess: Bool {
        if authState.isAdminPreview {
            return true
        }
        if let remoteUserProfile, remoteUserProfile.role == .staff {
            return true
        }
        return environment.appConfig.grantsStaffAccess(email: activeSession?.user.email)
    }

    var activeSession: AuthSession? {
        if case .authenticated(let session) = authState {
            return session
        }
        return nil
    }

    var sessionRole: SessionRole {
        switch authState {
        case .guest, .authenticating:
            return .guest
        case .authenticated:
            return hasStaffAccess ? .staff : .student
        case .adminPreview:
            return .adminPreview
        }
    }

    var accountDisplayName: String {
        switch authState {
        case .authenticated(let session):
            return session.user.displayName
        case .adminPreview:
            return "Admin Preview"
        case .guest, .authenticating:
            return profile?.displayName ?? "Guest"
        }
    }

    var accountSubtitle: String {
        switch authState {
        case .authenticated(let session):
            let suffix = hasStaffAccess ? " • staff tools enabled" : ""
            return "\(session.user.email)\(suffix)"
        case .adminPreview:
            return "Beta-only local bypass for demoing the full shell."
        case .authenticating:
            return "Completing Google sign-in."
        case .guest:
            return environment.appConfig.productionRequiresSignIn
                ? "Sign in with Google to access your AdmitPath workspace."
                : "Browse locally, then sign in with Google when you want sync."
        }
    }

    var lastSyncedAt: Date? {
        if case .synced(let date) = syncStatus {
            return date
        }
        return nil
    }

    var catalogFreshnessSummary: String {
        guard !environment.catalog.programs.isEmpty else {
            return "Bundled catalog unavailable."
        }
        let newestUpdate = environment.catalog.programs.map(\.lastUpdatedAt).max() ?? .now
        return "\(environment.catalog.programs.count) curated programs • freshest update \(formatDate(newestUpdate))"
    }

    var savedPrograms: [Program] {
        environment.programRepository.savedPrograms(in: demoState)
    }

    var comparedPrograms: [Program] {
        environment.programRepository.comparedPrograms(in: demoState)
    }

    var applications: [ApplicationRecord] {
        environment.applicationRepository.applications(in: demoState)
    }

    var trackedScholarships: [Scholarship] {
        environment.scholarshipRepository.trackedScholarships(in: demoState)
    }

    var scholarshipMatches: [ScholarshipMatch] {
        environment.scholarshipService.rankedScholarships(
            profile: profile,
            scholarships: environment.scholarshipRepository.allScholarships()
        )
    }

    var matches: [ProgramMatch] {
        environment.matchingService.rankedPrograms(
            profile: profile,
            filters: demoState.filters,
            universities: environment.catalog.universities,
            programs: environment.programRepository.allPrograms(),
            requirements: environment.catalog.requirements,
            deadlines: environment.catalog.deadlines,
            scholarships: scholarshipMatches
        )
    }

    var comparedMatches: [ProgramMatch] {
        matches.filter { demoState.comparisonProgramIDs.contains($0.program.id) }
    }

    var communityProfiles: [PeerProfile] {
        mergeProfiles(environment.communityRepository.allProfiles(), [activePeerProfile].compactMap { $0 })
    }

    var communityPosts: [PeerPost] {
        mergePosts(environment.communityRepository.allPosts(), demoState.userPosts)
    }

    var communityArtifacts: [PeerArtifact] {
        mergeArtifacts(environment.communityRepository.allArtifacts(), demoState.userArtifacts)
    }

    var bookmarkedPosts: [PeerPost] {
        communityPosts.filter { demoState.bookmarkedPostIDs.contains($0.id) }
    }

    var communityFeed: [FeedPost] {
        environment.communityRepository.feed(
            for: profile,
            shortlistProgramIDs: savedPrograms.map(\.id)
        )
    }

    var savedFeedPosts: [FeedPost] {
        communityFeed.filter { demoState.bookmarkedPostIDs.contains($0.post.id) }
    }

    var communityGroups: [CommunityGroup] {
        environment.communityRepository.groups(for: profile)
    }

    var affordabilityScenarios: [AffordabilityScenario] {
        matches
            .compactMap { $0.affordabilityScenario }
            .sorted { lhs, rhs in
                if lhs.remainingGapUSD != rhs.remainingGapUSD {
                    return lhs.remainingGapUSD < rhs.remainingGapUSD
                }
                return lhs.netCostAfterScholarshipsUSD < rhs.netCostAfterScholarshipsUSD
            }
    }

    var readinessScore: ReadinessScore {
        let profileScore = profile?.completenessScore ?? 0
        let testingScore: Int
        if let profile {
            if profile.degreeLevel == .undergrad {
                let hasEnglish = profile.englishTestType == .none || profile.englishTestScore > 0
                let hasStandardized = (profile.satScore ?? 0) > 0 || profile.standardizedTestStatus?.localizedCaseInsensitiveContains("waived") == true
                testingScore = (hasEnglish ? 50 : 0) + (hasStandardized ? 50 : 0)
            } else {
                testingScore = profile.englishTestType == .none || profile.englishTestScore > 0 ? 100 : 0
            }
        } else {
            testingScore = 0
        }
        let essaysScore: Int = {
            if demoState.sopProjects.contains(where: { !$0.generatedDraft.isEmpty }) { return 85 }
            if demoState.sopProjects.isNotEmpty { return 40 }
            return 0
        }()
        let applicationsScore: Int = applications.isEmpty ? 0 : applications.map(\.completionPercent).reduce(0, +) / applications.count
        let fundingScore: Int = {
            guard let scenario = affordabilityScenarios.first else { return profile?.scholarshipNeeded == true ? 35 : 70 }
            if scenario.remainingGapUSD == 0 { return 90 }
            if scenario.remainingGapUSD <= 10000 { return 65 }
            return 35
        }()

        var blockers: [String] = []
        if profileScore < 75 { blockers.append("Complete more of the student profile.") }
        if testingScore < 100 { blockers.append("Add or confirm testing status for application readiness.") }
        if essaysScore < 60 { blockers.append("Start the essay workspace before deadlines compress.") }
        if applicationsScore < 50 { blockers.append("Convert shortlist options into actionable applications.") }
        if fundingScore < 60 { blockers.append("Close the family funding gap with scholarships or loan planning.") }

        let overall = Int(Double(profileScore + testingScore + essaysScore + applicationsScore + fundingScore) / 5.0)

        return ReadinessScore(
            overall: overall,
            profile: profileScore,
            testing: testingScore,
            essays: essaysScore,
            applications: applicationsScore,
            funding: fundingScore,
            blockers: blockers
        )
    }

    var homeSnapshot: HomeSnapshot {
        let dueSoon = environment.deadlineService.dueSoonTasks(from: demoState.tasks)
        let nextDeadline = environment.deadlineService.nextDeadline(from: applications)
        let upcomingPlanner = environment.deadlineService.upcomingPlannerItems(from: demoState.plannerItems)
        let sopProgress = demoState.sopProjects.contains(where: { !$0.generatedDraft.isEmpty }) ? 80 : (demoState.sopProjects.isEmpty ? 0 : 35)
        let continueTitle: String
        let continueSubtitle: String

        if let nextPlanner = upcomingPlanner.first {
            continueTitle = "Continue: \(nextPlanner.title)"
            continueSubtitle = "Your next meaningful milestone is already mapped."
        } else if let nextTask = dueSoon.first {
            continueTitle = "Continue: \(nextTask.title)"
            continueSubtitle = "Your next meaningful task is already defined."
        } else if savedPrograms.isNotEmpty {
            continueTitle = "Continue: convert a shortlist into an application"
            continueSubtitle = "Turn saved programs into a concrete application plan."
        } else {
            continueTitle = "Continue: expand your shortlist"
            continueSubtitle = "Start with realistic multi-country options that fit your profile and budget."
        }

        return HomeSnapshot(
            profileCompleteness: profile?.completenessScore ?? 0,
            readinessScore: readinessScore,
            applicationsInProgress: applications.count,
            savedProgramsCount: savedPrograms.count,
            completedTaskCount: demoState.tasks.filter(\.isCompleted).count,
            pendingTaskCount: demoState.tasks.filter { !$0.isCompleted }.count,
            nextDeadline: nextDeadline,
            dueSoonTasks: dueSoon,
            upcomingPlannerItems: upcomingPlanner,
            recommendedScholarships: Array(scholarshipMatches.prefix(4)),
            topMatches: Array(matches.prefix(3)),
            communityHighlights: Array(communityPosts.prefix(3)),
            featuredFeed: Array(communityFeed.prefix(3)),
            fundingScenarios: Array(affordabilityScenarios.prefix(3)),
            sopProgress: sopProgress,
            continueTitle: continueTitle,
            continueSubtitle: continueSubtitle
        )
    }

    func start(forceReload: Bool = false) async {
        guard forceReload || !hasStarted else { return }
        hasStarted = true

        await refreshCatalog()

        if environment.runtimeOptions.loadSampleDataOnLaunch && isWorkspaceEmpty(guestStateCache) {
            guestStateCache = environment.resetService.sampleState(from: environment.catalog)
            if !isSignedIn {
                demoState = guestStateCache
                persistGuestStateSnapshot()
            }
        }

        if environment.runtimeOptions.forceGuestMode {
            authState = authState.isAdminPreview ? .adminPreview : .guest
            syncStatus = .localGuest
            remoteUserProfile = nil
            adminDashboard = .empty
            demoState = guestStateCache
            refreshNotifications()
            return
        }

        if authState.isAdminPreview {
            syncStatus = .localGuest
            remoteUserProfile = nil
            demoState = guestStateCache
            refreshNotifications()
            return
        }

        await restoreSessionFromStore()
    }

    func handleOpenURL(_ url: URL) async {
        do {
            guard let session = try await environment.authStore.resumeFromRedirectURL(url) else {
                return
            }
            authPrompt = nil
            await completeAuthenticatedLaunch(with: session)
        } catch {
            authState = .guest
            syncStatus = .localGuest
            remoteUserProfile = nil
            demoState = guestStateCache
            if !isCancellation(error) {
                surfaceWarning(title: "Google sign-in could not be completed", message: error.localizedDescription)
            }
        }
    }

    func signInWithGoogle() async {
        guard !isSignedIn else { return }
        authPrompt = nil
        authState = .authenticating
        syncStatus = .restoring

        do {
            let session = try await environment.authStore.signInWithGoogle(
                preferEphemeral: environment.runtimeOptions.preferEphemeralAuthSession
            )
            await completeAuthenticatedLaunch(with: session)
        } catch {
            authState = .guest
            syncStatus = .localGuest
            remoteUserProfile = nil
            demoState = guestStateCache
            if !isCancellation(error) {
                surfaceWarning(title: "Google sign-in failed", message: error.localizedDescription)
            }
        }
    }

    func signOut() async {
        cloudSaveTask?.cancel()
        let session = activeSession

        do {
            try await environment.authStore.signOut(session: session)
        } catch {
            surfaceWarning(title: "Sign out was only partially completed", message: error.localizedDescription)
        }

        authState = .guest
        syncStatus = .localGuest
        remoteUserProfile = nil
        adminDashboard = .empty
        demoState = guestStateCache
        refreshNotifications()
    }

    func dismissAuthPrompt() {
        authPrompt = nil
    }

    func setAdminPreviewEnabled(_ enabled: Bool) {
        guard canToggleAdminPreview else { return }
        authPrompt = nil
        authState = enabled ? .adminPreview : .guest
        syncStatus = .localGuest
        remoteUserProfile = nil
        adminDashboard = .empty
        demoState = guestStateCache
        refreshNotifications()
    }

    func replaceCloudStateWithGuestCache() {
        guard ensureProtectedFeatureAvailable(.applications) else { return }
        guard activeSession != nil else { return }
        demoState = guestStateCache
        persist()
    }

    func country(for program: Program) -> String {
        environment.programRepository.university(id: program.universityID)?.country ?? "Unknown"
    }

    func deadlines(for programID: String) -> [ProgramDeadline] {
        environment.programRepository.deadlines(for: programID)
    }

    func requirement(for programID: String) -> ProgramRequirement? {
        environment.programRepository.requirement(for: programID)
    }

    func scholarships(for program: Program) -> [ScholarshipMatch] {
        scholarshipMatches.filter { match in
            match.scholarship.destinationCountries.contains(country(for: program))
                && match.scholarship.eligibleDegreeLevels.contains(program.degreeLevel)
                && match.scholarship.eligibleSubjects.contains(where: {
                    $0.caseInsensitiveCompare(program.subjectArea) == .orderedSame
                })
        }
    }

    func communityPosts(for program: Program) -> [PeerPost] {
        communityPosts.filter { post in
            if post.country != country(for: program) { return false }
            if post.subjectArea.caseInsensitiveCompare(program.subjectArea) != .orderedSame { return false }
            if post.degreeLevel != program.degreeLevel { return false }
            if let postProgramID = post.programID {
                return postProgramID == program.id
            }
            return true
        }
    }

    func communityArtifacts(for program: Program) -> [PeerArtifact] {
        communityArtifacts.filter { artifact in
            if artifact.country != country(for: program) { return false }
            if artifact.subjectArea.caseInsensitiveCompare(program.subjectArea) != .orderedSame { return false }
            if artifact.degreeLevel != program.degreeLevel { return false }
            if let artifactProgramID = artifact.programID {
                return artifactProgramID == program.id
            }
            return true
        }
    }

    func replies(for postID: String) -> [PeerReply] {
        mergeReplies(environment.communityRepository.replies(for: postID), demoState.userReplies.filter { $0.postID == postID })
    }

    func author(for post: PeerPost) -> PeerProfile? {
        author(id: post.authorID)
    }

    func author(id: String) -> PeerProfile? {
        if activePeerProfile?.id == id {
            return activePeerProfile
        }
        return communityProfiles.first { $0.id == id }
    }

    func application(for programID: String) -> ApplicationRecord? {
        environment.applicationRepository.application(for: programID, in: demoState)
    }

    func applicationRecord(id: String) -> ApplicationRecord? {
        applications.first { $0.id == id }
    }

    func match(for programID: String) -> ProgramMatch? {
        matches.first { $0.program.id == programID }
    }

    func tasks(for applicationID: String) -> [ApplicationTask] {
        environment.applicationRepository.tasks(for: applicationID, in: demoState)
    }

    func plannerItems(for applicationID: String) -> [PlannerItem] {
        environment.applicationRepository.plannerItems(for: applicationID, in: demoState)
    }

    func applicationSystem(for country: String) -> ApplicationSystem {
        switch country {
        case "United States":
            return .commonApp
        case "United Kingdom":
            return .ucas
        default:
            return .direct
        }
    }

    func requirementItems(for programID: String) -> [RequirementItem] {
        guard let requirement = requirement(for: programID) else { return [] }
        let checklist = documentsChecklist()
        let readyByDocument = Dictionary(uniqueKeysWithValues: checklist.map { ($0.type, $0.isReady) })

        return [
            RequirementItem(id: "\(programID)_transcript", title: "Transcript", detail: "Academic records and grading details.", isComplete: readyByDocument[.transcript] ?? false),
            RequirementItem(id: "\(programID)_essay", title: "Essay / Personal Statement", detail: requirement.sopRequired ? "Required for this application pathway." : "Optional or not listed.", isComplete: readyByDocument[.sop] ?? false),
            RequirementItem(id: "\(programID)_lors", title: "Recommendations", detail: "\(requirement.lorCount) recommender(s) expected.", isComplete: readyByDocument[.lor] ?? false),
            RequirementItem(id: "\(programID)_scores", title: "Test Scores", detail: "English test plus any country-specific standardized tests.", isComplete: readyByDocument[.englishScores] ?? false),
            RequirementItem(id: "\(programID)_financials", title: "Funding Evidence", detail: requirement.financialProofRequired ? "Financial proof is required." : "Financial proof not explicitly listed.", isComplete: readyByDocument[.financialDocuments] ?? false)
        ]
    }

    func completeOnboarding(with profile: StudentProfile) {
        guard ensureWorkspaceMutationAllowed() else { return }
        var updated = profile
        updated.onboardingComplete = true
        environment.profileRepository.save(profile: updated, in: &demoState)
        persist()
    }

    func updateProfile(_ profile: StudentProfile) {
        guard ensureWorkspaceMutationAllowed() else { return }
        environment.profileRepository.save(profile: profile, in: &demoState)
        persist()
    }

    func updateFilters(_ filters: MatchFilters) {
        guard ensureWorkspaceMutationAllowed() else { return }
        demoState.filters = filters
        persist()
    }

    func toggleSavedProgram(_ programID: String) {
        guard ensureProtectedFeatureAvailable(.saveProgram) else { return }
        if environment.programRepository.isSaved(programID: programID, in: demoState) {
            environment.programRepository.unsave(programID: programID, in: &demoState)
        } else {
            environment.programRepository.save(programID: programID, in: &demoState)
        }
        persist()
    }

    func toggleComparedProgram(_ programID: String) {
        guard ensureProtectedFeatureAvailable(.comparePrograms) else { return }
        environment.programRepository.toggleCompared(programID: programID, in: &demoState)
        persist()
    }

    func toggleTrackedScholarship(_ scholarshipID: String) {
        guard ensureWorkspaceMutationAllowed() else { return }
        environment.scholarshipRepository.toggleTrackedScholarship(id: scholarshipID, in: &demoState)
        persist()
    }

    func toggleBookmarkedPost(_ postID: String) {
        guard ensureProtectedFeatureAvailable(.bookmarks) else { return }
        environment.communityRepository.toggleBookmark(postID: postID, in: &demoState)
        persist()
    }

    func reportPost(_ postID: String, reason: String = "Needs moderator review") {
        guard ensureProtectedFeatureAvailable(.reports) else { return }
        guard ensureWorkspaceMutationAllowed(feature: .reports) else { return }
        environment.communityRepository.report(postID: postID, reason: reason, in: &demoState)
        let report = demoState.reports.last
        persist()

        guard let report, let session = activeSession else { return }
        Task {
            do {
                try await self.environment.cloudCommunityStore.submitReport(report, session: session)
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Report saved locally only", message: error.localizedDescription)
                }
            }
        }
    }

    func requestVerification(note: String) {
        guard ensureProtectedFeatureAvailable(.communityArtifact) else { return }
        guard ensureWorkspaceMutationAllowed(feature: .communityArtifact) else { return }

        let request = VerificationRequest(
            id: "verification_\(demoState.verificationRequests.count + 1)",
            note: note,
            createdAt: .now,
            status: .underReview
        )
        demoState.verificationRequests.append(request)
        persist()

        guard let session = activeSession else { return }
        Task {
            do {
                try await self.environment.cloudCommunityStore.requestVerification(note: note, session: session)
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Verification request saved locally only", message: error.localizedDescription)
                }
            }
        }
    }

    func submitCommunityPost(
        title: String,
        body: String,
        kind: CommunityPostKind,
        country: String,
        subjectArea: String,
        degreeLevel: DegreeLevel,
        programID: String? = nil,
        scholarshipID: String? = nil,
        tags: [String] = []
    ) {
        guard ensureProtectedFeatureAvailable(.communityPost) else { return }
        guard ensureWorkspaceMutationAllowed(feature: .communityPost) else { return }
        guard let authorID = activePeerProfile?.id else { return }

        let post = PeerPost(
            id: "user_post_\(demoState.userPosts.count + 1)",
            authorID: authorID,
            title: title,
            body: body,
            kind: kind,
            country: country,
            subjectArea: subjectArea,
            degreeLevel: degreeLevel,
            programID: programID,
            scholarshipID: scholarshipID,
            tags: tags,
            moderationStatus: .underReview,
            createdAt: .now,
            upvoteCount: 0
        )
        demoState.userPosts.append(post)
        persist()

        guard let session = activeSession else { return }
        Task {
            do {
                try await self.environment.cloudCommunityStore.submitPost(post, session: session)
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Post saved locally only", message: error.localizedDescription)
                }
            }
        }
    }

    func submitReply(to postID: String, body: String, accepted: Bool = false) {
        guard ensureProtectedFeatureAvailable(.communityReply) else { return }
        guard ensureWorkspaceMutationAllowed(feature: .communityReply) else { return }
        guard let authorID = activePeerProfile?.id else { return }

        let reply = PeerReply(
            id: "user_reply_\(demoState.userReplies.count + 1)",
            postID: postID,
            authorID: authorID,
            body: body,
            createdAt: .now,
            moderationStatus: .underReview,
            isAcceptedAnswer: accepted
        )
        demoState.userReplies.append(reply)
        persist()

        guard let session = activeSession else { return }
        Task {
            do {
                try await self.environment.cloudCommunityStore.submitReply(reply, session: session)
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Reply saved locally only", message: error.localizedDescription)
                }
            }
        }
    }

    func submitArtifact(
        title: String,
        summary: String,
        kind: PeerArtifactKind,
        country: String,
        subjectArea: String,
        degreeLevel: DegreeLevel,
        programID: String? = nil,
        bulletHighlights: [String]
    ) {
        guard ensureProtectedFeatureAvailable(.communityArtifact) else { return }
        guard ensureWorkspaceMutationAllowed(feature: .communityArtifact) else { return }
        guard let author = activePeerProfile else { return }
        guard author.verificationStatus != .unverified || authState.isAdminPreview else {
            surfaceWarning(
                title: "Verification required",
                message: "Only verified students, admits, or alumni can publish trusted artifacts."
            )
            return
        }

        let artifact = PeerArtifact(
            id: "user_artifact_\(demoState.userArtifacts.count + 1)",
            authorID: author.id,
            programID: programID,
            title: title,
            summary: summary,
            kind: kind,
            country: country,
            subjectArea: subjectArea,
            degreeLevel: degreeLevel,
            verificationStatus: author.verificationStatus,
            moderationStatus: .underReview,
            createdAt: .now,
            bulletHighlights: bulletHighlights
        )
        demoState.userArtifacts.append(artifact)
        persist()

        guard let session = activeSession else { return }
        Task {
            do {
                try await self.environment.cloudCommunityStore.submitArtifact(artifact, session: session)
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Artifact saved locally only", message: error.localizedDescription)
                }
            }
        }
    }

    @discardableResult
    func createApplication(from programID: String) -> ApplicationRecord? {
        guard ensureProtectedFeatureAvailable(.applications) else { return nil }
        guard ensureWorkspaceMutationAllowed(feature: .applications) else { return nil }
        guard let program = environment.programRepository.program(id: programID) else { return nil }
        let deadline = environment.programRepository.nextDeadline(for: programID) ?? ProgramDeadline(
            id: "deadline_\(programID)",
            programID: programID,
            intakeTerm: program.intakeTerms.first ?? "Next Intake",
            applicationDeadline: Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now,
            scholarshipDeadline: nil,
            depositDeadline: nil,
            interviewWindowStart: nil,
            visaPrepStart: nil,
            decisionExpected: nil,
            notes: ""
        )
        let applicationID = "app_\(program.id)"
        let tasks = environment.taskGenerationService.generateTasks(
            applicationID: applicationID,
            requirement: environment.programRepository.requirement(for: programID),
            deadline: deadline.applicationDeadline,
            profile: profile
        )
        let plannerItems = environment.deadlineService.plannerItems(
            applicationID: applicationID,
            tasks: tasks,
            deadline: deadline
        )
        let application = environment.applicationRepository.createApplication(
            from: program,
            country: country(for: program),
            deadline: deadline,
            tasks: tasks,
            plannerItems: plannerItems,
            in: &demoState
        )
        if !environment.programRepository.isSaved(programID: programID, in: demoState) {
            environment.programRepository.save(programID: programID, in: &demoState)
        }
        persist()
        return application
    }

    func updateApplicationStatus(_ status: ApplicationStatus, applicationID: String) {
        guard ensureWorkspaceMutationAllowed(feature: .applications) else { return }
        environment.applicationRepository.update(applicationID: applicationID, status: status, in: &demoState)
        persist()
    }

    func updateApplicationNotes(_ notes: String, applicationID: String) {
        guard ensureWorkspaceMutationAllowed(feature: .applications) else { return }
        environment.applicationRepository.update(applicationID: applicationID, notes: notes, in: &demoState)
        persist()
    }

    func toggleTask(_ taskID: String, applicationID: String) {
        guard ensureWorkspaceMutationAllowed(feature: .applications) else { return }
        guard environment.applicationRepository.toggleTask(taskID: taskID, in: &demoState) != nil else { return }
        let tasks = environment.applicationRepository.tasks(for: applicationID, in: demoState)
        let completion = environment.taskGenerationService.completionPercent(for: tasks)
        environment.applicationRepository.update(applicationID: applicationID, completion: completion, in: &demoState)

        let updatedStatus: ApplicationStatus
        if tasks.contains(where: { $0.taskType == .submit && $0.isCompleted }) {
            updatedStatus = .submitted
        } else {
            switch completion {
            case 85...:
                updatedStatus = .readyToApply
            case 55..<85:
                updatedStatus = .preparingDocs
            case 20..<55:
                updatedStatus = .researching
            default:
                updatedStatus = .shortlisted
            }
        }
        environment.applicationRepository.update(applicationID: applicationID, status: updatedStatus, in: &demoState)
        persist()
    }

    func saveSOPProject(
        title: String,
        programID: String?,
        scholarshipID: String? = nil,
        mode: SOPProjectMode,
        answers: [SOPQuestionAnswer],
        generatedOutline: [String]? = nil,
        generatedDraft: String? = nil,
        critiqueFlags: [SOPCritiqueFlag]? = nil
    ) {
        guard ensureProtectedFeatureAvailable(.sopProjects) else { return }
        guard ensureWorkspaceMutationAllowed(feature: .sopProjects) else { return }
        guard let profile else { return }

        let existing = environment.sopRepository.project(for: programID, mode: mode, in: demoState)
        let program = programID.flatMap { environment.programRepository.program(id: $0) }
        let scholarship = scholarshipID.flatMap { environment.scholarshipRepository.scholarship(id: $0) }

        let outline = generatedOutline ?? environment.sopGenerationService.generateOutline(
            profile: profile,
            program: program,
            scholarship: scholarship,
            mode: mode,
            answers: answers
        )
        let draft = generatedDraft ?? environment.sopGenerationService.generateDraft(
            profile: profile,
            program: program,
            scholarship: scholarship,
            mode: mode,
            answers: answers
        )
        let flags = critiqueFlags ?? environment.sopGenerationService.critique(
            draft: draft,
            answers: answers,
            mode: mode
        )

        let project = buildSOPProject(
            existing: existing,
            title: title,
            mode: mode,
            program: program,
            scholarship: scholarship,
            answers: answers,
            outline: outline,
            draft: draft,
            critiqueFlags: flags
        )
        environment.sopRepository.save(project: project, in: &demoState)
        persist()
    }

    func documentsChecklist() -> [DocumentChecklistItem] {
        let sopReady = demoState.sopProjects.contains(where: { !$0.generatedDraft.isEmpty })
        let cvReady = demoState.tasks.contains(where: { $0.taskType == .cv && $0.isCompleted })
        let lorTasks = demoState.tasks.filter { $0.taskType == .lor }
        let lorReady = lorTasks.isEmpty || lorTasks.allSatisfy(\.isCompleted)
        let transcriptReady = demoState.tasks.contains(where: { $0.taskType == .transcript && $0.isCompleted })
        let passportReady = demoState.tasks.filter { $0.taskType == .passport }.allSatisfy(\.isCompleted)
        let scholarshipEssayReady = demoState.tasks.filter { $0.taskType == .scholarshipEssay }.allSatisfy(\.isCompleted)
        let portfolioReady = demoState.tasks.filter { $0.taskType == .portfolio }.allSatisfy(\.isCompleted)
        let englishReady = (profile?.englishTestScore ?? 0) > 0
        let financialReady = demoState.tasks.filter { $0.taskType == .financialProof }.allSatisfy(\.isCompleted)
            || (profile?.effectiveAnnualBudgetUSD ?? 0) > 0

        return [
            DocumentChecklistItem(type: .sop, isReady: sopReady, supportingNote: sopReady ? "Draft available with critique flags and version history." : "Start the guided questionnaire."),
            DocumentChecklistItem(type: .cv, isReady: cvReady, supportingNote: cvReady ? "CV task marked complete." : "Still pending for at least one application."),
            DocumentChecklistItem(type: .lor, isReady: lorReady, supportingNote: lorReady ? "Recommendation tasks are complete." : "One or more recommender actions remain."),
            DocumentChecklistItem(type: .transcript, isReady: transcriptReady, supportingNote: transcriptReady ? "Transcript requested or ready." : "Transcript task is still open."),
            DocumentChecklistItem(type: .englishScores, isReady: englishReady, supportingNote: englishReady ? "English score recorded in profile." : "Add an English test score in profile."),
            DocumentChecklistItem(type: .passport, isReady: passportReady, supportingNote: passportReady ? "Passport task is complete." : "Passport copy is still needed."),
            DocumentChecklistItem(type: .financialDocuments, isReady: financialReady, supportingNote: financialReady ? "Funding evidence is on file." : "Prepare bank statements or sponsor proof."),
            DocumentChecklistItem(type: .scholarshipEssay, isReady: scholarshipEssayReady, supportingNote: scholarshipEssayReady ? "Scholarship base essay is drafted." : "Draft a funding-specific variant if needed."),
            DocumentChecklistItem(type: .portfolio, isReady: portfolioReady, supportingNote: portfolioReady ? "Portfolio requirement is covered." : "Only relevant for selected programs.")
        ]
    }

    func loadSampleData() {
        guard ensureWorkspaceMutationAllowed() else { return }
        if isSignedIn {
            demoState = environment.resetService.sampleState(from: environment.catalog)
            persist()
            return
        }

        guestStateCache = environment.resetService.sampleState(from: environment.catalog)
        demoState = guestStateCache
        persistGuestStateSnapshot()
    }

    func resetAllData() {
        cloudSaveTask?.cancel()
        guard ensureWorkspaceMutationAllowed() || activeSession == nil else { return }

        do {
            try environment.stateStore.reset()
        } catch {
            surfaceWarning(title: "Reset could not clear prior storage first", message: error.localizedDescription)
        }

        guestStateCache = environment.resetService.emptyState()
        demoState = activeSession == nil ? guestStateCache : demoState
        if activeSession == nil {
            demoState = guestStateCache
        } else {
            demoState = environment.resetService.emptyState()
            persist()
        }

        selectedTab = .today
        routedProgram = nil
        routedApplication = nil
        routedSOPProject = nil

        if activeSession == nil {
            persistGuestStateSnapshot()
        }
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) {
        guard ensureWorkspaceMutationAllowed() else { return }
        demoState.notifications = preferences
        persist()
    }

    func saveOnboardingDraft(_ profile: StudentProfile) {
        guard ensureWorkspaceMutationAllowed() else { return }
        environment.profileRepository.save(profile: profile, in: &demoState)
        persist()
    }

    func retryCloudSync() async {
        if let session = activeSession {
            await completeAuthenticatedLaunch(with: session)
        } else {
            await start(forceReload: true)
        }
    }

    func refreshAdminDashboard() async {
        guard hasStaffAccess, let session = activeSession else {
            adminDashboard = .empty
            return
        }

        isLoadingAdminDashboard = true
        defer { isLoadingAdminDashboard = false }

        do {
            adminDashboard = try await environment.adminStore.fetchDashboard(
                session: session,
                catalog: environment.catalog
            )
        } catch {
            surfaceWarning(title: "Staff dashboard unavailable", message: error.localizedDescription)
        }
    }

    func updateReportStatus(_ reportID: String, status: ModerationStatus) {
        guard hasStaffAccess else { return }
        guard let session = activeSession else { return }

        if let index = demoState.reports.firstIndex(where: { $0.id == reportID }) {
            demoState.reports[index].status = status
        }
        if let index = adminDashboard.reports.firstIndex(where: { $0.id == reportID }) {
            adminDashboard.reports[index].status = status
        }

        Task {
            do {
                try await self.environment.adminStore.updateReportStatus(
                    reportID: reportID,
                    status: status,
                    session: session
                )
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Could not update report status", message: error.localizedDescription)
                }
            }
        }
    }

    func updateVerificationRequest(
        requestID: String,
        userID: String,
        verificationStatus: VerificationStatus
    ) {
        guard hasStaffAccess else { return }
        guard let session = activeSession else { return }

        if let index = adminDashboard.verificationRequests.firstIndex(where: { $0.id == requestID }) {
            adminDashboard.verificationRequests[index].status = .clear
        }
        if remoteUserProfile?.id == userID {
            remoteUserProfile?.verificationStatus = verificationStatus
        }

        Task {
            do {
                try await self.environment.adminStore.updateVerificationRequest(
                    requestID: requestID,
                    userID: userID,
                    verificationStatus: verificationStatus,
                    session: session
                )
                await self.refreshAdminDashboard()
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Could not update verification", message: error.localizedDescription)
                }
            }
        }
    }

    func markProgramFreshness(_ programID: String, dataFreshness: String = "Updated Today") {
        guard hasStaffAccess else { return }
        guard let session = activeSession else { return }

        Task {
            do {
                try await self.environment.adminStore.markProgramFreshness(
                    programID: programID,
                    dataFreshness: dataFreshness,
                    updatedAt: .now,
                    session: session
                )
                await self.refreshCatalog()
                await self.refreshAdminDashboard()
            } catch {
                await MainActor.run {
                    self.surfaceWarning(title: "Could not refresh program metadata", message: error.localizedDescription)
                }
            }
        }
    }

    func retryBootstrap() {
        cloudSaveTask?.cancel()
        hasStarted = false

        let result = AppEnvironment.bootstrap(
            bundle: bundle,
            fileManager: fileManager,
            baseDirectory: baseDirectory
        )

        environment = result.environment
        guestStateCache = result.initialState
        demoState = result.initialState
        launchState = result.launchState
        authState = environment.runtimeOptions.enableAdminPreviewOnLaunch && environment.appConfig.enableAdminPreview ? .adminPreview : .guest
        syncStatus = .localGuest
        remoteUserProfile = nil
        adminDashboard = .empty
        selectedTab = .today
        routedProgram = nil
        routedApplication = nil
        routedSOPProject = nil
        refreshNotifications()

        Task {
            await self.start(forceReload: true)
        }
    }

    func dismissLaunchNotice() {
        guard case .warning = launchState else { return }
        launchState = .ready
    }

    func openContinueFlow() {
        if let nextTask = homeSnapshot.dueSoonTasks.first {
            selectedTab = .apply
            routedApplication = RoutedApplication(id: nextTask.applicationID)
            return
        }

        if let topMatch = homeSnapshot.topMatches.first {
            selectedTab = .discover
            routedProgram = RoutedProgram(id: topMatch.program.id)
            return
        }

        openDocuments(programID: demoState.sopProjects.first?.programID)
    }

    func openProgram(_ programID: String) {
        selectedTab = .discover
        routedProgram = RoutedProgram(id: programID)
    }

    func openApplication(_ applicationID: String) {
        selectedTab = .apply
        routedApplication = RoutedApplication(id: applicationID)
    }

    func openDocuments(programID: String? = nil) {
        selectedTab = .apply
        let project = demoState.sopProjects.first(where: { $0.programID == programID }) ?? demoState.sopProjects.first
        routedSOPProject = RoutedSOPProject(
            id: project?.id ?? "master_sop",
            programID: project?.programID ?? programID
        )
    }

    func openFunding() {
        selectedTab = .funding
    }

    private var activePeerProfile: PeerProfile? {
        switch authState {
        case .authenticated(let session):
            let verificationStatus = remoteUserProfile?.verificationStatus ?? .unverified
            let peerRole: PeerRole
            switch verificationStatus {
            case .unverified:
                peerRole = .applicant
            case .verifiedStudent:
                peerRole = .student
            case .verifiedAdmit:
                peerRole = .admit
            case .verifiedAlumni:
                peerRole = .alumni
            }
            return PeerProfile(
                id: session.user.id,
                displayName: session.user.displayName,
                nationality: profile?.nationality ?? "Bangladesh",
                currentCountry: profile?.currentCountry ?? "Bangladesh",
                role: peerRole,
                verificationStatus: verificationStatus,
                currentUniversity: profile?.undergraduateInstitution.nonEmptyValue ?? "Prospective Applicant",
                currentProgram: profile?.subjectArea ?? "Study Abroad Planning",
                bio: "Signed in via Google for AdmitPath beta.",
                subjectAreas: [profile?.subjectArea].compactMap { $0 },
                targetCountries: profile?.preferredCountries ?? [],
                reputationScore: 0,
                outcomes: []
            )
        case .adminPreview:
            return PeerProfile(
                id: "admin_preview_user",
                displayName: "Admin Preview",
                nationality: "Bangladesh",
                currentCountry: "Bangladesh",
                role: .alumni,
                verificationStatus: .verifiedAlumni,
                currentUniversity: "AdmitPath Ops",
                currentProgram: "Beta QA",
                bio: "Local-only admin preview for private beta validation.",
                subjectAreas: AppConstants.supportedSubjects,
                targetCountries: AppConstants.supportedCountries,
                reputationScore: 999,
                outcomes: []
            )
        case .guest, .authenticating:
            return nil
        }
    }

    private func restoreSessionFromStore() async {
        syncStatus = .restoring

        do {
            guard let session = try await environment.authStore.restoreSession() else {
                authState = .guest
                syncStatus = .localGuest
                remoteUserProfile = nil
                demoState = guestStateCache
                refreshNotifications()
                return
            }
            await completeAuthenticatedLaunch(with: session)
        } catch {
            authState = .guest
            syncStatus = .localGuest
            remoteUserProfile = nil
            demoState = guestStateCache
            refreshNotifications()
            try? await environment.authStore.signOut(session: nil)
            surfaceWarning(title: "Using guest mode", message: error.localizedDescription)
        }
    }

    private func completeAuthenticatedLaunch(with session: AuthSession) async {
        do {
            let refreshed = try await environment.authStore.refreshSessionIfNeeded(session)
            authState = .authenticated(refreshed)
            syncStatus = .syncing

            try await environment.workspaceStore.upsertUserProfile(session: refreshed)
            let fetchedProfile = try await environment.workspaceStore.fetchRemoteUserProfile(session: refreshed)
            remoteUserProfile = mergeRemoteProfile(fetchedProfile, with: refreshed)
            let remoteWorkspace = try await environment.workspaceStore.fetchWorkspace(session: refreshed)

            if let remoteWorkspace, !isWorkspaceEmpty(remoteWorkspace) {
                demoState = remoteWorkspace
            } else if hasMeaningfulGuestCache {
                demoState = guestStateCache
                refreshNotifications()
                try await environment.workspaceStore.saveWorkspace(demoState, session: refreshed)
            } else {
                demoState = remoteWorkspace ?? environment.resetService.emptyState()
            }

            refreshNotifications()
            syncStatus = .synced(Date())
            if hasStaffAccess {
                await refreshAdminDashboard()
            } else {
                adminDashboard = .empty
            }
        } catch {
            authState = .authenticated(session)
            remoteUserProfile = mergeRemoteProfile(remoteUserProfile, with: session)
            syncStatus = mapSyncStatus(for: error)
            demoState = guestStateCache
            refreshNotifications()
            surfaceWarning(title: "Cloud workspace unavailable", message: error.localizedDescription)
        }
    }

    private func refreshCatalog() async {
        do {
            let updatedCatalog = try await environment.catalogStore.fetchPreferredCatalog(fallback: environment.catalog)
            if updatedCatalog != environment.catalog {
                environment = environment.replacingCatalog(updatedCatalog)
            }
        } catch {
            surfaceWarning(title: "Using bundled catalog", message: error.localizedDescription)
        }
    }

    private func mergeProfiles(_ lhs: [PeerProfile], _ rhs: [PeerProfile]) -> [PeerProfile] {
        var merged: [String: PeerProfile] = [:]
        for profile in lhs + rhs {
            merged[profile.id] = profile
        }
        return merged.values.sorted { $0.reputationScore > $1.reputationScore }
    }

    private func mergePosts(_ lhs: [PeerPost], _ rhs: [PeerPost]) -> [PeerPost] {
        var merged: [String: PeerPost] = [:]
        for post in lhs + rhs where post.moderationStatus != .limited {
            merged[post.id] = post
        }
        return merged.values.sorted { $0.createdAt > $1.createdAt }
    }

    private func mergeReplies(_ lhs: [PeerReply], _ rhs: [PeerReply]) -> [PeerReply] {
        var merged: [String: PeerReply] = [:]
        for reply in lhs + rhs where reply.moderationStatus != .limited {
            merged[reply.id] = reply
        }
        return merged.values.sorted { left, right in
            if left.isAcceptedAnswer != right.isAcceptedAnswer {
                return left.isAcceptedAnswer && !right.isAcceptedAnswer
            }
            return left.createdAt < right.createdAt
        }
    }

    private func mergeArtifacts(_ lhs: [PeerArtifact], _ rhs: [PeerArtifact]) -> [PeerArtifact] {
        var merged: [String: PeerArtifact] = [:]
        for artifact in lhs + rhs where artifact.moderationStatus == .clear || artifact.moderationStatus == .underReview {
            merged[artifact.id] = artifact
        }
        return merged.values.sorted { left, right in
            if rank(for: left.verificationStatus) != rank(for: right.verificationStatus) {
                return rank(for: left.verificationStatus) > rank(for: right.verificationStatus)
            }
            return left.createdAt > right.createdAt
        }
    }

    private func rank(for status: VerificationStatus) -> Int {
        switch status {
        case .unverified:
            return 0
        case .verifiedStudent:
            return 1
        case .verifiedAdmit:
            return 2
        case .verifiedAlumni:
            return 3
        }
    }

    private var hasMeaningfulGuestCache: Bool {
        !isWorkspaceEmpty(guestStateCache)
    }

    private func isWorkspaceEmpty(_ state: DemoState) -> Bool {
        state == .empty
    }

    private func ensureProtectedFeatureAvailable(_ feature: ProtectedFeature) -> Bool {
        switch authState {
        case .adminPreview:
            return true
        case .authenticated:
            return ensureWorkspaceMutationAllowed(feature: feature)
        case .guest, .authenticating:
            authPrompt = AuthPrompt(feature: feature)
            return false
        }
    }

    private func ensureWorkspaceMutationAllowed(feature: ProtectedFeature? = nil) -> Bool {
        switch authState {
        case .adminPreview:
            return true
        case .authenticated:
            guard syncStatus.canWriteCloud else {
                surfaceWarning(title: "Cloud sync is unavailable", message: syncStatus.summary)
                return false
            }
            return true
        case .guest:
            if requiresAuthenticationGate, let feature {
                authPrompt = AuthPrompt(feature: feature)
                return false
            }
            return true
        case .authenticating:
            return false
        }
    }

    private func refreshNotifications() {
        demoState.lastGeneratedNotifications = environment.deadlineService.suggestedNotifications(
            tasks: demoState.tasks,
            applications: demoState.applications,
            plannerItems: demoState.plannerItems,
            preferences: demoState.notifications
        )
    }

    private func persist() {
        refreshNotifications()

        if activeSession != nil {
            persistCloudStateSnapshot()
        } else {
            guestStateCache = demoState
            persistGuestStateSnapshot()
        }
    }

    private func persistGuestStateSnapshot() {
        do {
            try environment.stateStore.save(demoState)
        } catch {
            surfaceWarning(title: "Changes are not being saved locally", message: error.localizedDescription)
        }
    }

    private func persistCloudStateSnapshot() {
        guard let session = activeSession else {
            return
        }

        let snapshot = demoState
        syncStatus = .syncing
        cloudSaveTask?.cancel()
        cloudSaveTask = Task {
            do {
                let refreshed = try await self.environment.authStore.refreshSessionIfNeeded(session)
                try await self.environment.workspaceStore.saveWorkspace(snapshot, session: refreshed)
                await MainActor.run {
                    self.authState = .authenticated(refreshed)
                    self.syncStatus = .synced(Date())
                }
            } catch {
                await MainActor.run {
                    self.syncStatus = self.mapSyncStatus(for: error)
                    self.surfaceWarning(title: "Cloud sync failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func mapSyncStatus(for error: Error) -> SyncStatus {
        if let error = error as? RuntimeServiceError {
            switch error {
            case .networkUnavailable(let message):
                return .requiresNetwork(message)
            case .unauthorized(let message):
                return .failed(message)
            case .notConfigured(let message),
                    .invalidResponse(let message),
                    .invalidCallback(let message),
                    .unsupported(let message):
                return .failed(message)
            case .cancelled:
                return .failed("The sign-in flow was cancelled.")
            }
        }

        if let error = error as? URLError {
            return .requiresNetwork(error.localizedDescription)
        }

        return .failed(error.localizedDescription)
    }

    private func mergeRemoteProfile(_ profile: RemoteUserProfile?, with session: AuthSession) -> RemoteUserProfile {
        let role: UserProfileRole = if environment.appConfig.grantsStaffAccess(email: session.user.email) {
            .staff
        } else {
            profile?.role ?? .student
        }

        return RemoteUserProfile(
            id: session.user.id,
            email: session.user.email,
            displayName: profile?.displayName ?? session.user.displayName,
            avatarURL: profile?.avatarURL ?? session.user.avatarURL,
            role: role,
            verificationStatus: profile?.verificationStatus ?? .unverified,
            googleProvider: profile?.googleProvider ?? session.user.provider
        )
    }

    private func buildSOPProject(
        existing: SOPProject?,
        title: String,
        mode: SOPProjectMode,
        program: Program?,
        scholarship: Scholarship?,
        answers: [SOPQuestionAnswer],
        outline: [String],
        draft: String,
        critiqueFlags: [SOPCritiqueFlag]
    ) -> SOPProject {
        let previousVersions = existing?.versions ?? []
        let nextVersionNumber = (previousVersions.last?.versionNumber ?? 0) + 1
        let baseID = existing?.id ?? "sop_\(program?.id ?? scholarship?.id ?? mode.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let version = SOPVersion(
            id: "\(baseID)_v\(nextVersionNumber)",
            versionNumber: nextVersionNumber,
            content: draft,
            createdAt: .now
        )

        return SOPProject(
            id: baseID,
            programID: program?.id ?? existing?.programID,
            scholarshipID: scholarship?.id ?? existing?.scholarshipID,
            title: title,
            mode: mode,
            questionnaireAnswers: answers,
            generatedOutline: outline,
            generatedDraft: draft,
            critiqueFlags: critiqueFlags,
            versions: previousVersions + [version],
            updatedAt: .now
        )
    }

    private func isCancellation(_ error: Error) -> Bool {
        if let runtimeError = error as? RuntimeServiceError, case .cancelled = runtimeError {
            return true
        }
        return false
    }

    private func surfaceWarning(title: String, message: String) {
        guard !launchState.isBlocking else { return }
        launchState = .warning(AppLaunchNotice(title: title, message: message))
    }
}

private extension String {
    var nonEmptyValue: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
