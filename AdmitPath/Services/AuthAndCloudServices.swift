import CryptoKit
import Foundation
import Security

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum RuntimeServiceError: LocalizedError {
    case notConfigured(String)
    case invalidResponse(String)
    case invalidCallback(String)
    case networkUnavailable(String)
    case unauthorized(String)
    case cancelled
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message),
                .invalidResponse(let message),
                .invalidCallback(let message),
                .networkUnavailable(let message),
                .unauthorized(let message),
                .unsupported(let message):
            return message
        case .cancelled:
            return "The sign-in flow was cancelled."
        }
    }
}

protocol AuthSessionStoring: AnyObject, Sendable {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear() throws
}

final class InMemoryAuthSessionStore: AuthSessionStoring, @unchecked Sendable {
    private var session: AuthSession?

    init(seed: AuthSession? = nil) {
        self.session = seed
    }

    func load() throws -> AuthSession? {
        session
    }

    func save(_ session: AuthSession) throws {
        self.session = session
    }

    func clear() throws {
        session = nil
    }
}

final class KeychainAuthSessionStore: AuthSessionStoring, @unchecked Sendable {
    private let service: String
    private let account = "primary-session"

    init(service: String = "AdmitPath.AuthSession") {
        self.service = service
    }

    func load() throws -> AuthSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw RuntimeServiceError.invalidResponse("Could not restore the saved Google session from the keychain.")
        }
        return try FormatterFactory.makeJSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) throws {
        let data = try FormatterFactory.makeJSONEncoder().encode(session)
        var query = baseQuery()
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw RuntimeServiceError.invalidResponse("Could not update the Google session in the keychain.")
            }
            return
        }

        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw RuntimeServiceError.invalidResponse("Could not save the Google session to the keychain.")
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RuntimeServiceError.invalidResponse("Could not clear the Google session from the keychain.")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

protocol NetworkClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionNetworkClient: NetworkClient, Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RuntimeServiceError.invalidResponse("The server returned a non-HTTP response.")
        }
        return (data, httpResponse)
    }
}

protocol WebAuthenticationClient {
    func authenticate(url: URL, callbackScheme: String, preferEphemeral: Bool) async throws -> URL
}

#if canImport(AuthenticationServices)
@MainActor
final class LiveWebAuthenticationClient: NSObject, WebAuthenticationClient, ASWebAuthenticationPresentationContextProviding {
    func authenticate(url: URL, callbackScheme: String, preferEphemeral: Bool) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session: ASWebAuthenticationSession
            if #available(iOS 17.4, macOS 14.4, *) {
                session = ASWebAuthenticationSession(
                    url: url,
                    callback: .customScheme(callbackScheme)
                ) { callbackURL, error in
                    if let error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            continuation.resume(throwing: RuntimeServiceError.cancelled)
                            return
                        }
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL else {
                        continuation.resume(throwing: RuntimeServiceError.invalidCallback("The browser did not return a callback URL."))
                        return
                    }
                    continuation.resume(returning: callbackURL)
                }
            } else {
                session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: callbackScheme
                ) { callbackURL, error in
                    if let error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            continuation.resume(throwing: RuntimeServiceError.cancelled)
                            return
                        }
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL else {
                        continuation.resume(throwing: RuntimeServiceError.invalidCallback("The browser did not return a callback URL."))
                        return
                    }
                    continuation.resume(returning: callbackURL)
                }
            }
            session.prefersEphemeralWebBrowserSession = preferEphemeral
            session.presentationContextProvider = self
            if !session.start() {
                continuation.resume(throwing: RuntimeServiceError.invalidResponse("The Google sign-in flow could not be started."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif

struct PKCEPayload: Hashable {
    var state: String
    var verifier: String
    var challenge: String

    static func generate() -> PKCEPayload {
        let verifier = randomURLSafeString(length: 64)
        let challengeData = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(challengeData)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return PKCEPayload(
            state: randomURLSafeString(length: 32),
            verifier: verifier,
            challenge: challenge
        )
    }

    private static func randomURLSafeString(length: Int) -> String {
        let count = max(32, length)
        let bytes = (0..<count).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

protocol AuthStore: Sendable {
    func restoreSession() async throws -> AuthSession?
    func signInWithGoogle(preferEphemeral: Bool) async throws -> AuthSession
    func resumeFromRedirectURL(_ url: URL) async throws -> AuthSession?
    func refreshSessionIfNeeded(_ session: AuthSession) async throws -> AuthSession
    func signOut(session: AuthSession?) async throws
}

protocol CatalogStore: Sendable {
    func fetchPreferredCatalog(fallback: CatalogData) async throws -> CatalogData
}

protocol WorkspaceStore: Sendable {
    func fetchRemoteUserProfile(session: AuthSession) async throws -> RemoteUserProfile?
    func fetchWorkspace(session: AuthSession) async throws -> DemoState?
    func saveWorkspace(_ state: DemoState, session: AuthSession) async throws
    func upsertUserProfile(session: AuthSession) async throws
}

protocol CommunityStore: Sendable {
    func submitReport(_ report: CommunityReport, session: AuthSession) async throws
    func submitPost(_ post: PeerPost, session: AuthSession) async throws
    func submitReply(_ reply: PeerReply, session: AuthSession) async throws
    func submitArtifact(_ artifact: PeerArtifact, session: AuthSession) async throws
    func requestVerification(note: String, session: AuthSession) async throws
}

protocol AdminStore: Sendable {
    func fetchDashboard(session: AuthSession, catalog: CatalogData) async throws -> AdminDashboardSnapshot
    func updateReportStatus(reportID: String, status: ModerationStatus, session: AuthSession) async throws
    func updateVerificationRequest(
        requestID: String,
        userID: String,
        verificationStatus: VerificationStatus,
        session: AuthSession
    ) async throws
    func markProgramFreshness(
        programID: String,
        dataFreshness: String,
        updatedAt: Date,
        session: AuthSession
    ) async throws
}

struct GeneratedSOPContent: Hashable, Codable {
    var outline: [String]
    var draft: String
    var critiqueFlags: [SOPCritiqueFlag]
}

protocol SOPGateway: Sendable {
    func generate(
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship?,
        mode: SOPProjectMode,
        answers: [SOPQuestionAnswer]
    ) async throws -> GeneratedSOPContent
}

final class MockAuthStore: AuthStore, @unchecked Sendable {
    private let sessionStore: AuthSessionStoring
    private let seedSession: AuthSession

    init(sessionStore: AuthSessionStoring, seedSession: AuthSession = .mock) {
        self.sessionStore = sessionStore
        self.seedSession = seedSession
    }

    func restoreSession() async throws -> AuthSession? {
        try sessionStore.load()
    }

    func signInWithGoogle(preferEphemeral: Bool) async throws -> AuthSession {
        try sessionStore.save(seedSession)
        return seedSession
    }

    func resumeFromRedirectURL(_ url: URL) async throws -> AuthSession? {
        guard url.absoluteString.hasPrefix(AppConfig.fallback.authCallbackPrefix) else {
            return nil
        }
        try sessionStore.save(seedSession)
        return seedSession
    }

    func refreshSessionIfNeeded(_ session: AuthSession) async throws -> AuthSession {
        session
    }

    func signOut(session: AuthSession?) async throws {
        try sessionStore.clear()
    }
}

final class SupabaseAuthStore: AuthStore, @unchecked Sendable {
    private let config: AppConfig
    private let networkClient: NetworkClient
    private let sessionStore: AuthSessionStoring
    private let webAuthenticationClient: WebAuthenticationClient
    private var pendingPKCE: PKCEPayload?

    init(
        config: AppConfig,
        networkClient: NetworkClient,
        sessionStore: AuthSessionStoring,
        webAuthenticationClient: WebAuthenticationClient
    ) {
        self.config = config
        self.networkClient = networkClient
        self.sessionStore = sessionStore
        self.webAuthenticationClient = webAuthenticationClient
    }

    func restoreSession() async throws -> AuthSession? {
        guard let stored = try sessionStore.load() else { return nil }
        return try await refreshSessionIfNeeded(stored)
    }

    func signInWithGoogle(preferEphemeral: Bool) async throws -> AuthSession {
        guard config.isConfigured else {
            throw RuntimeServiceError.notConfigured("Supabase Google auth is not configured yet. Update AppConfig.json with a real project URL and anon key.")
        }
        let pkce = PKCEPayload.generate()
        pendingPKCE = pkce
        let authURL = try makeGoogleAuthURL(pkce: pkce)
        let callbackURL = try await webAuthenticationClient.authenticate(
            url: authURL,
            callbackScheme: config.redirectScheme,
            preferEphemeral: preferEphemeral
        )
        return try await completeSession(from: callbackURL, pkce: pkce)
    }

    func resumeFromRedirectURL(_ url: URL) async throws -> AuthSession? {
        guard url.absoluteString.hasPrefix(config.authCallbackPrefix) else {
            return nil
        }
        let pkce = pendingPKCE ?? PKCEPayload.generate()
        return try await completeSession(from: url, pkce: pkce)
    }

    func refreshSessionIfNeeded(_ session: AuthSession) async throws -> AuthSession {
        guard session.isExpired else { return session }

        var request = try makeRequest(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]
        )
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode([
            "refresh_token": session.refreshToken
        ])

        let tokenResponse: SupabaseTokenResponse = try await performDecodingRequest(request)
        let refreshed = tokenResponse.session
        try sessionStore.save(refreshed)
        return refreshed
    }

    func signOut(session: AuthSession?) async throws {
        if let session, config.isConfigured {
            var request = try makeRequest(path: "/auth/v1/logout", method: "POST", accessToken: session.accessToken)
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await networkClient.data(for: request)
        }
        pendingPKCE = nil
        try sessionStore.clear()
    }

    private func completeSession(from callbackURL: URL, pkce: PKCEPayload) async throws -> AuthSession {
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let description = queryItems.first(where: { $0.name == "error_description" })?.value ?? error
            throw RuntimeServiceError.invalidCallback(description)
        }
        guard let state = queryItems.first(where: { $0.name == "state" })?.value,
              state == pkce.state else {
            throw RuntimeServiceError.invalidCallback("The Google callback returned an unexpected OAuth state.")
        }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw RuntimeServiceError.invalidCallback("The Google callback did not include an authorization code.")
        }

        var request = try makeRequest(
            path: "/auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "pkce")]
        )
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode([
            "auth_code": code,
            "code_verifier": pkce.verifier
        ])

        let tokenResponse: SupabaseTokenResponse = try await performDecodingRequest(request)
        let session = tokenResponse.session
        try sessionStore.save(session)
        pendingPKCE = nil
        return session
    }

    private func makeGoogleAuthURL(pkce: PKCEPayload) throws -> URL {
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: config.redirectURL.absoluteString),
            URLQueryItem(name: "scopes", value: config.googleScopes),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "access_type", value: "offline")
        ]
        guard let url = components?.url else {
            throw RuntimeServiceError.invalidResponse("Could not construct the Google authorization URL.")
        }
        return url
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil
    ) throws -> URLRequest {
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        var components = URLComponents(url: baseURL.appendingPathComponent(String(path.dropFirst())), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw RuntimeServiceError.invalidResponse("Could not build the backend request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func performDecodingRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(response.statusCode)"
            throw RuntimeServiceError.invalidResponse(message)
        }
        return try FormatterFactory.makeJSONDecoder().decode(T.self, from: data)
    }
}

struct BundledCatalogStore: CatalogStore {
    func fetchPreferredCatalog(fallback: CatalogData) async throws -> CatalogData {
        fallback
    }
}

struct SupabaseCatalogStore: CatalogStore {
    let config: AppConfig
    let networkClient: NetworkClient

    func fetchPreferredCatalog(fallback: CatalogData) async throws -> CatalogData {
        guard config.enableRemoteCatalog, config.isConfigured else {
            return fallback
        }

        async let universities: [University] = fetch(table: "universities")
        async let programs: [Program] = fetch(table: "programs")
        async let requirements: [ProgramRequirement] = fetch(table: "program_requirements")
        async let deadlines: [ProgramDeadline] = fetch(table: "program_deadlines")
        async let scholarships: [Scholarship] = fetch(table: "scholarships")
        async let peerProfiles: [PeerProfile] = fetch(table: "peer_profiles")
        async let peerPosts: [PeerPost] = fetch(table: "peer_posts")
        async let peerReplies: [PeerReply] = fetch(table: "peer_replies")
        async let peerArtifacts: [PeerArtifact] = fetch(table: "peer_artifacts")

        do {
            return CatalogData(
                universities: try await universities,
                programs: try await programs,
                requirements: try await requirements,
                deadlines: try await deadlines,
                scholarships: try await scholarships,
                peerProfiles: try await peerProfiles,
                peerPosts: try await peerPosts,
                peerReplies: try await peerReplies,
                peerArtifacts: try await peerArtifacts,
                sampleProfile: fallback.sampleProfile,
                sampleApplications: fallback.sampleApplications,
                sampleTasks: fallback.sampleTasks
            )
        } catch {
            return fallback
        }
    }

    private func fetch<T: Decodable>(table: String) async throws -> [T] {
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "select", value: "*")]
        guard let url = components?.url else {
            throw RuntimeServiceError.invalidResponse("Could not build the remote catalog request.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw RuntimeServiceError.invalidResponse("Remote catalog request failed for \(table).")
        }
        return try FormatterFactory.makeJSONDecoder().decode([T].self, from: data)
    }
}

final class PreviewWorkspaceStore: WorkspaceStore, @unchecked Sendable {
    private var state: DemoState?
    private var profile: RemoteUserProfile?

    init(seedState: DemoState? = nil, seedProfile: RemoteUserProfile? = nil) {
        self.state = seedState
        self.profile = seedProfile
    }

    func fetchRemoteUserProfile(session: AuthSession) async throws -> RemoteUserProfile? {
        profile
    }

    func fetchWorkspace(session: AuthSession) async throws -> DemoState? {
        state
    }

    func saveWorkspace(_ state: DemoState, session: AuthSession) async throws {
        self.state = state
    }

    func upsertUserProfile(session: AuthSession) async throws {
        profile = RemoteUserProfile(
            id: session.user.id,
            email: session.user.email,
            displayName: session.user.displayName,
            avatarURL: session.user.avatarURL,
            role: profile?.role ?? .student,
            verificationStatus: profile?.verificationStatus ?? .unverified,
            googleProvider: session.user.provider
        )
    }
}

struct SupabaseWorkspaceStore: WorkspaceStore {
    let config: AppConfig
    let networkClient: NetworkClient

    func fetchRemoteUserProfile(session: AuthSession) async throws -> RemoteUserProfile? {
        guard config.enableRemoteWorkspace, config.isConfigured else {
            return nil
        }

        var request = try makeRequest(
            path: "user_profiles",
            method: "GET",
            accessToken: session.accessToken,
            queryItems: [
                URLQueryItem(name: "select", value: "id,email,displayName,avatarURL,role,verificationStatus,googleProvider"),
                URLQueryItem(name: "id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        request.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await networkClient.data(for: request)
        if response.statusCode == 406 {
            return nil
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Could not load the signed-in profile."
            throw RuntimeServiceError.invalidResponse(message)
        }
        return try FormatterFactory.makeJSONDecoder().decode(RemoteUserProfile.self, from: data)
    }

    func fetchWorkspace(session: AuthSession) async throws -> DemoState? {
        guard config.enableRemoteWorkspace, config.isConfigured else {
            return nil
        }
        var request = try makeRequest(
            path: "user_workspaces",
            method: "GET",
            accessToken: session.accessToken,
            queryItems: [
                URLQueryItem(name: "select", value: "workspace,updatedAt"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        request.setValue("application/vnd.pgrst.object+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await networkClient.data(for: request)
        if response.statusCode == 406 {
            return nil
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Could not load the cloud workspace."
            throw RuntimeServiceError.invalidResponse(message)
        }
        let workspace = try FormatterFactory.makeJSONDecoder().decode(WorkspaceEnvelope.self, from: data)
        return workspace.workspace
    }

    func saveWorkspace(_ state: DemoState, session: AuthSession) async throws {
        guard config.enableRemoteWorkspace, config.isConfigured else {
            return
        }
        let row = WorkspaceUpsertRow(
            userID: session.user.id,
            workspace: state,
            updatedAt: Date()
        )
        var request = try makeRequest(
            path: "user_workspaces",
            method: "POST",
            accessToken: session.accessToken,
            queryItems: [URLQueryItem(name: "on_conflict", value: "user_id")]
        )
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode([row])

        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Could not save the cloud workspace."
            throw RuntimeServiceError.invalidResponse(message)
        }
    }

    func upsertUserProfile(session: AuthSession) async throws {
        guard config.enableRemoteWorkspace, config.isConfigured else {
            return
        }
        let row = UserProfileUpsertRow(
            id: session.user.id,
            email: session.user.email,
            displayName: session.user.displayName,
            avatarURL: session.user.avatarURL,
            googleProvider: session.user.provider
        )
        var request = try makeRequest(
            path: "user_profiles",
            method: "POST",
            accessToken: session.accessToken,
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")]
        )
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode([row])

        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Could not upsert the signed-in user profile."
            throw RuntimeServiceError.invalidResponse(message)
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        accessToken: String,
        queryItems: [URLQueryItem]
    ) throws -> URLRequest {
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(path)"), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw RuntimeServiceError.invalidResponse("Could not build the workspace request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

struct PreviewCommunityStore: CommunityStore {
    func submitReport(_ report: CommunityReport, session: AuthSession) async throws {}
    func submitPost(_ post: PeerPost, session: AuthSession) async throws {}
    func submitReply(_ reply: PeerReply, session: AuthSession) async throws {}
    func submitArtifact(_ artifact: PeerArtifact, session: AuthSession) async throws {}
    func requestVerification(note: String, session: AuthSession) async throws {}
}

struct PreviewAdminStore: AdminStore {
    var snapshot: AdminDashboardSnapshot = .empty

    func fetchDashboard(session: AuthSession, catalog: CatalogData) async throws -> AdminDashboardSnapshot {
        if snapshot.stalePrograms.isEmpty {
            let stalePrograms = catalog.programs
                .sorted { $0.lastUpdatedAt < $1.lastUpdatedAt }
                .prefix(5)
                .map { program in
                    CatalogFreshnessItem(
                        program: program,
                        country: catalog.universities.first(where: { $0.id == program.universityID })?.country ?? "Unknown"
                    )
                }
            return AdminDashboardSnapshot(
                reports: snapshot.reports,
                verificationRequests: snapshot.verificationRequests,
                stalePrograms: stalePrograms
            )
        }
        return snapshot
    }

    func updateReportStatus(reportID: String, status: ModerationStatus, session: AuthSession) async throws {}

    func updateVerificationRequest(
        requestID: String,
        userID: String,
        verificationStatus: VerificationStatus,
        session: AuthSession
    ) async throws {}

    func markProgramFreshness(
        programID: String,
        dataFreshness: String,
        updatedAt: Date,
        session: AuthSession
    ) async throws {}
}

struct SupabaseCommunityStore: CommunityStore {
    let config: AppConfig
    let networkClient: NetworkClient

    func submitReport(_ report: CommunityReport, session: AuthSession) async throws {
        try await postRows([report], to: "community_reports", session: session)
    }

    func submitPost(_ post: PeerPost, session: AuthSession) async throws {
        try await postRows([post], to: "peer_posts", session: session)
    }

    func submitReply(_ reply: PeerReply, session: AuthSession) async throws {
        try await postRows([reply], to: "peer_replies", session: session)
    }

    func submitArtifact(_ artifact: PeerArtifact, session: AuthSession) async throws {
        try await postRows([artifact], to: "peer_artifacts", session: session)
    }

    func requestVerification(note: String, session: AuthSession) async throws {
        let row = VerificationRequestRow(
            userID: session.user.id,
            note: note,
            createdAt: Date(),
            status: ModerationStatus.underReview.rawValue
        )
        try await postRows([row], to: "verification_requests", session: session)
    }

    private func postRows<T: Encodable>(_ rows: [T], to table: String, session: AuthSession) async throws {
        guard config.enableRemoteWorkspace, config.isConfigured else {
            return
        }
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        let url = baseURL.appendingPathComponent("rest/v1/\(table)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode(rows)

        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Could not save community content."
            throw RuntimeServiceError.invalidResponse(message)
        }
    }
}

struct SupabaseAdminStore: AdminStore {
    let config: AppConfig
    let networkClient: NetworkClient

    func fetchDashboard(session: AuthSession, catalog: CatalogData) async throws -> AdminDashboardSnapshot {
        async let reports: [CommunityReport] = fetch(table: "community_reports", session: session)
        async let verificationRequests: [VerificationRequestRecord] = fetch(table: "verification_requests", session: session)

        let resolvedReports = try await reports.sorted { $0.createdAt > $1.createdAt }
        let resolvedVerificationRequests = try await verificationRequests.sorted { $0.createdAt > $1.createdAt }
        let stalePrograms = catalog.programs
            .sorted { $0.lastUpdatedAt < $1.lastUpdatedAt }
            .prefix(8)
            .map { program in
                CatalogFreshnessItem(
                    program: program,
                    country: catalog.universities.first(where: { $0.id == program.universityID })?.country ?? "Unknown"
                )
            }

        return AdminDashboardSnapshot(
            reports: resolvedReports,
            verificationRequests: resolvedVerificationRequests,
            stalePrograms: stalePrograms
        )
    }

    func updateReportStatus(reportID: String, status: ModerationStatus, session: AuthSession) async throws {
        _ = try await performStaffAction(
            payload: StaffActionPayload(
                action: "update_report_status",
                reportID: reportID,
                requestID: nil,
                userID: nil,
                programID: nil,
                status: status.rawValue,
                verificationStatus: nil,
                dataFreshness: nil,
                updatedAt: nil
            ),
            session: session
        )
    }

    func updateVerificationRequest(
        requestID: String,
        userID: String,
        verificationStatus: VerificationStatus,
        session: AuthSession
    ) async throws {
        _ = try await performStaffAction(
            payload: StaffActionPayload(
                action: "update_verification_status",
                reportID: nil,
                requestID: requestID,
                userID: userID,
                programID: nil,
                status: nil,
                verificationStatus: verificationStatus.rawValue,
                dataFreshness: nil,
                updatedAt: nil
            ),
            session: session
        )
    }

    func markProgramFreshness(
        programID: String,
        dataFreshness: String,
        updatedAt: Date,
        session: AuthSession
    ) async throws {
        _ = try await performStaffAction(
            payload: StaffActionPayload(
                action: "mark_program_freshness",
                reportID: nil,
                requestID: nil,
                userID: nil,
                programID: programID,
                status: nil,
                verificationStatus: nil,
                dataFreshness: dataFreshness,
                updatedAt: updatedAt
            ),
            session: session
        )
    }

    private func fetch<T: Decodable>(table: String, session: AuthSession) async throws -> [T] {
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "select", value: "*")]
        guard let url = components?.url else {
            throw RuntimeServiceError.invalidResponse("Could not build the admin dashboard request.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Could not load the staff dashboard."
            throw RuntimeServiceError.invalidResponse(message)
        }
        return try FormatterFactory.makeJSONDecoder().decode([T].self, from: data)
    }

    private func performStaffAction(
        payload: StaffActionPayload,
        session: AuthSession
    ) async throws -> Data {
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw RuntimeServiceError.notConfigured("The Supabase URL in AppConfig.json is invalid.")
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("functions/v1/staff-ops"))
        request.httpMethod = "POST"
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode(payload)
        let (data, response) = try await networkClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Staff action failed."
            throw RuntimeServiceError.invalidResponse(message)
        }
        return data
    }
}

struct LocalSOPGateway: SOPGateway {
    let service: SOPGenerationService

    func generate(
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship?,
        mode: SOPProjectMode,
        answers: [SOPQuestionAnswer]
    ) async throws -> GeneratedSOPContent {
        GeneratedSOPContent(
            outline: service.generateOutline(profile: profile, program: program, scholarship: scholarship, mode: mode, answers: answers),
            draft: service.generateDraft(profile: profile, program: program, scholarship: scholarship, mode: mode, answers: answers),
            critiqueFlags: service.critique(
                draft: service.generateDraft(profile: profile, program: program, scholarship: scholarship, mode: mode, answers: answers),
                answers: answers,
                mode: mode
            )
        )
    }
}

struct SupabaseSOPGateway: SOPGateway {
    let config: AppConfig
    let networkClient: NetworkClient
    let fallback: SOPGateway

    func generate(
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship?,
        mode: SOPProjectMode,
        answers: [SOPQuestionAnswer]
    ) async throws -> GeneratedSOPContent {
        guard config.enableSOPGateway, config.isConfigured else {
            return try await fallback.generate(
                profile: profile,
                program: program,
                scholarship: scholarship,
                mode: mode,
                answers: answers
            )
        }

        guard let baseURL = URL(string: config.supabaseURL) else {
            return try await fallback.generate(
                profile: profile,
                program: program,
                scholarship: scholarship,
                mode: mode,
                answers: answers
            )
        }

        let payload = SOPGatewayRequest(
            profile: profile,
            program: program,
            scholarship: scholarship,
            mode: mode,
            answers: answers
        )
        var request = URLRequest(url: baseURL.appendingPathComponent("functions/v1/sop-generate"))
        request.httpMethod = "POST"
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try FormatterFactory.makeJSONEncoder().encode(payload)

        do {
            let (data, response) = try await networkClient.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                return try await fallback.generate(
                    profile: profile,
                    program: program,
                    scholarship: scholarship,
                    mode: mode,
                    answers: answers
                )
            }
            return try FormatterFactory.makeJSONDecoder().decode(GeneratedSOPContent.self, from: data)
        } catch {
            return try await fallback.generate(
                profile: profile,
                program: program,
                scholarship: scholarship,
                mode: mode,
                answers: answers
            )
        }
    }
}

private struct SupabaseTokenResponse: Decodable {
    var accessToken: String
    var refreshToken: String
    var tokenType: String
    var expiresIn: Int
    var user: SupabaseAuthUserPayload
    var providerToken: String?
    var providerRefreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
        case providerToken = "provider_token"
        case providerRefreshToken = "provider_refresh_token"
    }

    var session: AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            providerToken: providerToken,
            providerRefreshToken: providerRefreshToken,
            user: user.authUser
        )
    }
}

private struct SupabaseAuthUserPayload: Decodable {
    var id: String
    var email: String?
    var appMetadata: AppMetadataPayload?
    var userMetadata: UserMetadataPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case appMetadata = "app_metadata"
        case userMetadata = "user_metadata"
    }

    var authUser: AuthUser {
        let displayName = userMetadata?.fullName ?? userMetadata?.name ?? email ?? "AdmitPath Student"
        return AuthUser(
            id: id,
            email: email ?? "student@admitpath.app",
            displayName: displayName,
            avatarURL: userMetadata?.avatarURL ?? userMetadata?.picture,
            provider: appMetadata?.provider ?? "google"
        )
    }
}

private struct AppMetadataPayload: Decodable {
    var provider: String?
}

private struct UserMetadataPayload: Decodable {
    var name: String?
    var fullName: String?
    var avatarURL: String?
    var picture: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case avatarURL = "avatar_url"
        case picture
    }
}

private struct WorkspaceEnvelope: Codable {
    var workspace: DemoState
    var updatedAt: Date?
}

private struct WorkspaceUpsertRow: Codable {
    var userID: String
    var workspace: DemoState
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case workspace
        case updatedAt
    }
}

private struct UserProfileUpsertRow: Codable {
    var id: String
    var email: String
    var displayName: String
    var avatarURL: String?
    var googleProvider: String
}

private struct VerificationRequestRow: Codable {
    var userID: String
    var note: String
    var createdAt: Date
    var status: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case note
        case createdAt
        case status
    }
}

private struct StaffActionPayload: Codable {
    var action: String
    var reportID: String?
    var requestID: String?
    var userID: String?
    var programID: String?
    var status: String?
    var verificationStatus: String?
    var dataFreshness: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case action
        case reportID = "reportId"
        case requestID = "requestId"
        case userID = "userId"
        case programID = "programId"
        case status
        case verificationStatus
        case dataFreshness
        case updatedAt
    }
}

private struct SOPGatewayRequest: Codable {
    var profile: StudentProfile
    var program: Program?
    var scholarship: Scholarship?
    var mode: SOPProjectMode
    var answers: [SOPQuestionAnswer]
}

extension AuthSession {
    static let mock = AuthSession(
        accessToken: "mock-access-token",
        refreshToken: "mock-refresh-token",
        tokenType: "bearer",
        expiresAt: Date().addingTimeInterval(60 * 60 * 8),
        providerToken: "mock-google-token",
        providerRefreshToken: nil,
        user: AuthUser(
            id: "mock-user-id",
            email: "student@admitpath.app",
            displayName: "Mock Student",
            avatarURL: nil,
            provider: "google"
        )
    )
}
