import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct AppStateTests {
    @MainActor
    @Test
    func sampleDataAndResetPersistRoundTrip() throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let environment = makeEnvironment(catalog: catalog, baseDirectory: tempDirectory)
        let appState = AppState(environment: environment, initialState: .empty)

        appState.loadSampleData()

        let savedState = try environment.stateStore.load()
        #expect(savedState?.profile?.fullName == catalog.sampleProfile.fullName)
        #expect(savedState?.applications.count == catalog.sampleApplications.count)
        #expect(savedState?.trackedScholarshipIDs.isEmpty == false)
        #expect(savedState?.bookmarkedPostIDs.isEmpty == false)

        appState.resetAllData()

        let resetState = try environment.stateStore.load()
        #expect(resetState?.applications.isEmpty == true)
        #expect(resetState?.sopProjects.isEmpty == true)
        #expect(resetState?.bookmarkedPostIDs.isEmpty == true)
    }

    @MainActor
    @Test
    func createApplicationAndToggleTaskUpdatesState() throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let environment = makeEnvironment(catalog: catalog, baseDirectory: tempDirectory)
        var initialState = DemoState.empty
        initialState.profile = catalog.sampleProfile
        let appState = AppState(environment: environment, initialState: initialState)

        let programID = try #require(catalog.programs.first?.id)
        appState.setAdminPreviewEnabled(true)

        let application = try #require(appState.createApplication(from: programID))
        let tasks = appState.tasks(for: application.id)
        let firstTask = try #require(tasks.first)

        appState.toggleTask(firstTask.id, applicationID: application.id)

        let updatedTasks = appState.tasks(for: application.id)
        let updatedFirst = try #require(updatedTasks.first)
        #expect(updatedFirst.isCompleted)
        #expect(appState.applicationRecord(id: application.id)?.completionPercent ?? 0 >= 10)
        #expect(!appState.plannerItems(for: application.id).isEmpty)
    }

    @MainActor
    @Test
    func guestProtectedActionPresentsAuthPrompt() throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        var guestState = DemoState.empty
        guestState.profile = catalog.sampleProfile
        let environment = makeEnvironment(catalog: catalog, baseDirectory: tempDirectory)
        let appState = AppState(environment: environment, initialState: guestState)

        let programID = try #require(catalog.programs.first?.id)
        appState.toggleSavedProgram(programID)

        #expect(appState.authPrompt?.feature == .saveProgram)
        #expect(appState.savedPrograms.isEmpty)
    }

    @MainActor
    @Test
    func mockAuthenticatedLaunchImportsGuestWorkspaceWhenCloudIsEmpty() async throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let seededSessionStore = InMemoryAuthSessionStore(seed: .mock)
        let previewWorkspace = PreviewWorkspaceStore()
        let runtimeOptions = AppRuntimeOptions(
            useMockAuthenticatedSession: true,
            enableAdminPreviewOnLaunch: false,
            loadSampleDataOnLaunch: false,
            forceGuestMode: false,
            preferEphemeralAuthSession: true,
            baseDirectoryOverride: nil
        )
        let environment = makeEnvironment(
            catalog: catalog,
            baseDirectory: tempDirectory,
            runtimeOptions: runtimeOptions,
            authSessionStore: seededSessionStore,
            authStore: MockAuthStore(sessionStore: seededSessionStore),
            workspaceStore: previewWorkspace
        )
        let guestState = ResetService().sampleState(from: catalog)
        let appState = AppState(environment: environment, initialState: guestState)

        await appState.start()

        #expect(appState.isSignedIn)
        #expect(appState.syncStatus == .synced(appState.syncStatusDate ?? .distantFuture))
        #expect(appState.savedPrograms.count == guestState.savedProgramIDs.count)
        let cloudState = try await previewWorkspace.fetchWorkspace(session: .mock)
        #expect(cloudState?.savedProgramIDs == guestState.savedProgramIDs)
    }

    @MainActor
    @Test
    func remoteCatalogFailureFallsBackToBundledData() async throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let runtimeOptions = AppRuntimeOptions(
            useMockAuthenticatedSession: false,
            enableAdminPreviewOnLaunch: false,
            loadSampleDataOnLaunch: false,
            forceGuestMode: true,
            preferEphemeralAuthSession: false,
            baseDirectoryOverride: nil
        )
        let environment = makeEnvironment(
            catalog: catalog,
            baseDirectory: tempDirectory,
            runtimeOptions: runtimeOptions,
            catalogStore: FailingCatalogStore()
        )
        let appState = AppState(environment: environment, initialState: .empty)

        await appState.start()

        #expect(appState.environment.catalog.programs.count == catalog.programs.count)
        #expect(appState.launchState.notice?.title == "Using bundled catalog")
    }

    @MainActor
    @Test
    func signInFirstModeRequiresAuthenticationGateWithoutSession() async throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let environment = makeEnvironment(catalog: catalog, baseDirectory: tempDirectory)
        let appState = AppState(environment: environment, initialState: .empty)

        await appState.start()

        #expect(appState.requiresAuthenticationGate)
        #expect(appState.isSignedIn == false)
    }

    @MainActor
    @Test
    func syncFailureBlocksProtectedMutationsForSignedInUsers() async throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let seededSessionStore = InMemoryAuthSessionStore(seed: .mock)
        let environment = makeEnvironment(
            catalog: catalog,
            baseDirectory: tempDirectory,
            authSessionStore: seededSessionStore,
            authStore: MockAuthStore(sessionStore: seededSessionStore),
            workspaceStore: FailingWorkspaceStore()
        )
        var initialState = DemoState.empty
        initialState.profile = catalog.sampleProfile
        let appState = AppState(environment: environment, initialState: initialState)

        await appState.start()

        let programID = try #require(catalog.programs.first?.id)
        appState.toggleSavedProgram(programID)

        #expect(appState.savedPrograms.isEmpty)
        #expect(appState.launchState.notice?.title == "Cloud sync is unavailable")
    }

    @MainActor
    @Test
    func allowlistedStaffSessionExposesStaffRole() async throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let seededSessionStore = InMemoryAuthSessionStore(seed: .mock)
        let remoteProfile = RemoteUserProfile(
            id: AuthSession.mock.user.id,
            email: AuthSession.mock.user.email,
            displayName: AuthSession.mock.user.displayName,
            avatarURL: nil,
            role: .staff,
            verificationStatus: .verifiedStudent,
            googleProvider: "google"
        )
        let workspaceStore = PreviewWorkspaceStore(seedProfile: remoteProfile)

        var config = AppConfig.fallback
        config.staffAdminEmails = [AuthSession.mock.user.email]

        let environment = makeEnvironment(
            catalog: catalog,
            baseDirectory: tempDirectory,
            appConfig: config,
            authSessionStore: seededSessionStore,
            authStore: MockAuthStore(sessionStore: seededSessionStore),
            workspaceStore: workspaceStore
        )
        let appState = AppState(environment: environment, initialState: .empty)

        await appState.start()

        #expect(appState.sessionRole == .staff)
        #expect(appState.hasStaffAccess)
        #expect(appState.remoteUserProfile?.verificationStatus == .verifiedStudent)
    }

    @MainActor
    @Test
    func roadmapNavigationRoutesToTodayDiscoverApplyAndFunding() throws {
        let catalog = try loadCatalog()
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let environment = makeEnvironment(catalog: catalog, baseDirectory: tempDirectory)
        var initialState = DemoState.empty
        initialState.profile = catalog.sampleProfile
        let appState = AppState(environment: environment, initialState: initialState)
        appState.setAdminPreviewEnabled(true)

        let programID = try #require(catalog.programs.first?.id)
        let application = try #require(appState.createApplication(from: programID))

        appState.openProgram(programID)
        #expect(appState.selectedTab == .discover)

        appState.openApplication(application.id)
        #expect(appState.selectedTab == .apply)

        appState.openDocuments(programID: programID)
        #expect(appState.selectedTab == .apply)

        appState.openFunding()
        #expect(appState.selectedTab == .funding)
    }

    private func loadCatalog() throws -> CatalogData {
        try DemoDataLoader(bundle: DemoDataLoader.bundledResourceBundle).loadCatalog()
    }

    private func makeTempDirectory() throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        return tempDirectory
    }

    private func makeEnvironment(
        catalog: CatalogData,
        baseDirectory: URL,
        appConfig: AppConfig = .fallback,
        runtimeOptions: AppRuntimeOptions = AppRuntimeOptions(
            useMockAuthenticatedSession: false,
            enableAdminPreviewOnLaunch: false,
            loadSampleDataOnLaunch: false,
            forceGuestMode: false,
            preferEphemeralAuthSession: false,
            baseDirectoryOverride: nil
        ),
        authSessionStore: AuthSessionStoring? = nil,
        authStore: AuthStore? = nil,
        catalogStore: CatalogStore? = nil,
        workspaceStore: WorkspaceStore? = nil,
        communityStore: CommunityStore? = nil,
        adminStore: AdminStore? = nil,
        sopGateway: SOPGateway? = nil
    ) -> AppEnvironment {
        let sessionStore = authSessionStore ?? InMemoryAuthSessionStore()

        return AppEnvironment(
            appConfig: appConfig,
            runtimeOptions: runtimeOptions,
            catalog: catalog,
            stateStore: DemoStateStore(baseDirectory: baseDirectory),
            authSessionStore: sessionStore,
            authStore: authStore ?? MockAuthStore(sessionStore: sessionStore),
            catalogStore: catalogStore ?? BundledCatalogStore(),
            workspaceStore: workspaceStore ?? PreviewWorkspaceStore(),
            cloudCommunityStore: communityStore ?? PreviewCommunityStore(),
            adminStore: adminStore ?? PreviewAdminStore(),
            sopGateway: sopGateway ?? LocalSOPGateway(service: SOPGenerationService()),
            profileRepository: ProfileRepository(),
            programRepository: ProgramRepository(catalog: catalog),
            scholarshipRepository: ScholarshipRepository(catalog: catalog),
            applicationRepository: ApplicationRepository(),
            sopRepository: SOPRepository(),
            communityRepository: CommunityRepository(catalog: catalog),
            matchingService: MatchingService(),
            scholarshipService: ScholarshipService(),
            affordabilityService: AffordabilityService(),
            taskGenerationService: TaskGenerationService(),
            deadlineService: DeadlineService(),
            sopGenerationService: SOPGenerationService(),
            resetService: ResetService()
        )
    }
}

private struct FailingCatalogStore: CatalogStore {
    func fetchPreferredCatalog(fallback: CatalogData) async throws -> CatalogData {
        throw RuntimeServiceError.networkUnavailable("Remote catalog unavailable for test.")
    }
}

private struct FailingWorkspaceStore: WorkspaceStore {
    func fetchRemoteUserProfile(session: AuthSession) async throws -> RemoteUserProfile? {
        nil
    }

    func fetchWorkspace(session: AuthSession) async throws -> DemoState? {
        throw RuntimeServiceError.networkUnavailable("No connectivity to restore the cloud workspace.")
    }

    func saveWorkspace(_ state: DemoState, session: AuthSession) async throws {
        throw RuntimeServiceError.networkUnavailable("No connectivity to save the cloud workspace.")
    }

    func upsertUserProfile(session: AuthSession) async throws {}
}

private extension AppState {
    var syncStatusDate: Date? {
        if case .synced(let date) = syncStatus {
            return date
        }
        return nil
    }
}
