import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct AuthRuntimeTests {
    @Test
    func pkcePayloadGeneratesDistinctURLSafeValues() {
        let first = PKCEPayload.generate()
        let second = PKCEPayload.generate()

        #expect(first.state != second.state)
        #expect(first.verifier != second.verifier)
        #expect(first.challenge != second.challenge)
        #expect(first.state.contains("+") == false)
        #expect(first.verifier.contains("/") == false)
        #expect(first.challenge.contains("=") == false)
    }

    @Test
    func mockAuthStoreRoundTripsSessionAndClearsOnSignOut() async throws {
        let sessionStore = InMemoryAuthSessionStore()
        let authStore = MockAuthStore(sessionStore: sessionStore)

        let signedIn = try await authStore.signInWithGoogle(preferEphemeral: true)
        let restored = try await authStore.restoreSession()

        #expect(restored == signedIn)

        try await authStore.signOut(session: restored)

        let cleared = try await authStore.restoreSession()
        #expect(cleared == nil)
    }

    @Test
    func localSOPGatewayProducesDraftAndCritique() async throws {
        let gateway = LocalSOPGateway(service: SOPGenerationService())
        let profile = StudentProfile.empty
        let answers = SOPGenerationService().makeAnswers(
            from: Array(repeating: "Concrete evidence about coursework, projects, and goals.", count: 6)
        )

        let generated = try await gateway.generate(
            profile: profile,
            program: nil,
            scholarship: nil,
            mode: .master,
            answers: answers
        )

        #expect(!generated.outline.isEmpty)
        #expect(!generated.draft.isEmpty)
        #expect(generated.critiqueFlags.isEmpty == false)
    }

    @Test
    func appConfigBuildsExpectedRedirectURLAndStaffAccess() {
        var config = AppConfig.fallback
        config.staffAdminEmails = ["staff@admitpath.app"]

        #expect(config.redirectURL.absoluteString == "admitpath://auth/callback")
        #expect(config.grantsStaffAccess(email: "staff@admitpath.app"))
        #expect(config.grantsStaffAccess(email: "student@admitpath.app") == false)
    }

    @Test
    func supabaseAuthStoreExchangesGoogleCallbackIntoSession() async throws {
        let sessionStore = InMemoryAuthSessionStore()
        let webClient = StubWebAuthenticationClient(
            callbackURL: URL(string: "admitpath://auth/callback?state=TEST_STATE&code=AUTH_CODE")!
        )
        let networkClient = StubNetworkClient(
            responses: [
                StubNetworkClient.Response(
                    path: "/auth/v1/token",
                    statusCode: 200,
                    body: try FormatterFactory.makeJSONEncoder().encode(
                        StubTokenPayload.make()
                    )
                )
            ]
        )
        let config = AppConfig(
            supabaseURL: "https://example.supabase.co",
            supabaseAnonKey: "public-anon-key",
            redirectScheme: "admitpath",
            redirectHost: "auth",
            redirectPath: "/callback",
            googleScopes: "openid email profile",
            enableRemoteCatalog: true,
            enableRemoteWorkspace: true,
            enableSOPGateway: true,
            productionRequiresSignIn: true,
            enableAdminPreview: true,
            enableTestMockAuth: true,
            staffAdminEmails: []
        )
        let authStore = SupabaseAuthStore(
            config: config,
            networkClient: networkClient,
            sessionStore: sessionStore,
            webAuthenticationClient: webClient
        )

        let session = try await authStore.signInWithGoogle(preferEphemeral: true)

        #expect(session.user.email == "student@admitpath.app")
        #expect(session.user.provider == "google")
        #expect(try sessionStore.load() == session)
    }
}

private final class StubWebAuthenticationClient: WebAuthenticationClient {
    let callbackURL: URL

    init(callbackURL: URL) {
        self.callbackURL = callbackURL
    }

    func authenticate(url: URL, callbackScheme: String, preferEphemeral: Bool) async throws -> URL {
        let authComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let state = authComponents?.queryItems?.first(where: { $0.name == "state" })?.value ?? "TEST_STATE"
        var components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code", value: "AUTH_CODE")
        ]
        return components?.url ?? callbackURL
    }
}

private struct StubNetworkClient: NetworkClient {
    struct Response {
        var path: String
        var statusCode: Int
        var body: Data
    }

    let responses: [Response]

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        guard let response = responses.first(where: { path.hasSuffix($0.path) || path == $0.path }) else {
            throw RuntimeServiceError.invalidResponse("Missing stubbed response for \(path)")
        }
        let httpResponse = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.supabase.co")!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response.body, httpResponse)
    }
}

private struct StubTokenPayload: Codable {
    var accessToken: String
    var refreshToken: String
    var tokenType: String
    var expiresIn: Int
    var user: StubUserPayload

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }

    static func make() -> StubTokenPayload {
        StubTokenPayload(
            accessToken: "live-access-token",
            refreshToken: "refresh-token",
            tokenType: "bearer",
            expiresIn: 3600,
            user: StubUserPayload(
                id: "user_123",
                email: "student@admitpath.app",
                appMetadata: ["provider": "google"],
                userMetadata: [
                    "full_name": "Test Student",
                    "avatar_url": "https://example.com/avatar.png"
                ]
            )
        )
    }
}

private struct StubUserPayload: Codable {
    var id: String
    var email: String
    var appMetadata: [String: String]
    var userMetadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case appMetadata = "app_metadata"
        case userMetadata = "user_metadata"
    }
}
