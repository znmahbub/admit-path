import Foundation

struct AppEnvironment {
    let appConfig: AppConfig
    let runtimeOptions: AppRuntimeOptions
    let catalog: CatalogData
    let stateStore: DemoStateStore
    let authSessionStore: AuthSessionStoring
    let authStore: AuthStore
    let catalogStore: CatalogStore
    let workspaceStore: WorkspaceStore
    let cloudCommunityStore: CommunityStore
    let adminStore: AdminStore
    let sopGateway: SOPGateway
    let profileRepository: ProfileRepository
    let programRepository: ProgramRepository
    let scholarshipRepository: ScholarshipRepository
    let applicationRepository: ApplicationRepository
    let sopRepository: SOPRepository
    let communityRepository: CommunityRepository
    let matchingService: MatchingService
    let scholarshipService: ScholarshipService
    let affordabilityService: AffordabilityService
    let taskGenerationService: TaskGenerationService
    let deadlineService: DeadlineService
    let sopGenerationService: SOPGenerationService
    let resetService: ResetService

    @MainActor
    static func bootstrap(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil
    ) -> BootstrapResult {
        let runtimeOptions = AppRuntimeOptions.current()
        let resolvedBaseDirectory = baseDirectory ?? runtimeOptions.baseDirectoryOverride
        let stateStore = DemoStateStore(fileManager: fileManager, baseDirectory: resolvedBaseDirectory)
        let appConfig = AppConfigLoader.load(bundle: bundle)
        let networkClient = URLSessionNetworkClient()
        let authSessionStore: AuthSessionStoring
        let authStore: AuthStore
        let workspaceStore: WorkspaceStore
        let cloudCommunityStore: CommunityStore
        let adminStore: AdminStore

        if runtimeOptions.useMockAuthenticatedSession && appConfig.enableTestMockAuth {
            let inMemoryStore = InMemoryAuthSessionStore(seed: .mock)
            authSessionStore = inMemoryStore
            authStore = MockAuthStore(sessionStore: inMemoryStore)
            workspaceStore = PreviewWorkspaceStore()
            cloudCommunityStore = PreviewCommunityStore()
            adminStore = PreviewAdminStore()
        } else {
            authSessionStore = KeychainAuthSessionStore()
            #if canImport(AuthenticationServices)
            authStore = SupabaseAuthStore(
                config: appConfig,
                networkClient: networkClient,
                sessionStore: authSessionStore,
                webAuthenticationClient: LiveWebAuthenticationClient()
            )
            #else
            authStore = MockAuthStore(sessionStore: authSessionStore)
            #endif
            workspaceStore = SupabaseWorkspaceStore(config: appConfig, networkClient: networkClient)
            cloudCommunityStore = SupabaseCommunityStore(config: appConfig, networkClient: networkClient)
            adminStore = SupabaseAdminStore(config: appConfig, networkClient: networkClient)
        }

        let catalogStore = SupabaseCatalogStore(config: appConfig, networkClient: networkClient)
        let sopGateway = SupabaseSOPGateway(
            config: appConfig,
            networkClient: networkClient,
            fallback: LocalSOPGateway(service: SOPGenerationService())
        )

        let catalog: CatalogData
        let launchState: AppLaunchState

        do {
            catalog = try DemoDataLoader(bundle: bundle).loadCatalog()
            launchState = .ready
        } catch {
            catalog = .empty
            launchState = .failed(
                AppLaunchNotice(
                    title: "Bundled demo data unavailable",
                    message: error.localizedDescription
                )
            )
        }

        let environment = AppEnvironment(
            appConfig: appConfig,
            runtimeOptions: runtimeOptions,
            catalog: catalog,
            stateStore: stateStore,
            authSessionStore: authSessionStore,
            authStore: authStore,
            catalogStore: catalogStore,
            workspaceStore: workspaceStore,
            cloudCommunityStore: cloudCommunityStore,
            adminStore: adminStore,
            sopGateway: sopGateway,
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

        do {
            let initialState = try stateStore.load() ?? environment.resetService.emptyState()
            return BootstrapResult(
                environment: environment,
                initialState: initialState,
                launchState: launchState
            )
        } catch {
            let warning = AppLaunchNotice(
                title: "Saved progress could not be restored",
                message: error.localizedDescription
            )
            return BootstrapResult(
                environment: environment,
                initialState: environment.resetService.emptyState(),
                launchState: launchState.isBlocking ? launchState : .warning(warning)
            )
        }
    }

    func replacingCatalog(_ catalog: CatalogData) -> AppEnvironment {
        AppEnvironment(
            appConfig: appConfig,
            runtimeOptions: runtimeOptions,
            catalog: catalog,
            stateStore: stateStore,
            authSessionStore: authSessionStore,
            authStore: authStore,
            catalogStore: catalogStore,
            workspaceStore: workspaceStore,
            cloudCommunityStore: cloudCommunityStore,
            adminStore: adminStore,
            sopGateway: sopGateway,
            profileRepository: profileRepository,
            programRepository: ProgramRepository(catalog: catalog),
            scholarshipRepository: ScholarshipRepository(catalog: catalog),
            applicationRepository: applicationRepository,
            sopRepository: sopRepository,
            communityRepository: CommunityRepository(catalog: catalog),
            matchingService: matchingService,
            scholarshipService: scholarshipService,
            affordabilityService: affordabilityService,
            taskGenerationService: taskGenerationService,
            deadlineService: deadlineService,
            sopGenerationService: sopGenerationService,
            resetService: resetService
        )
    }
}
