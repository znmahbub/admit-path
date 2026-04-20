import Foundation

struct AppConfig: Codable, Hashable {
    var supabaseURL: String
    var supabaseAnonKey: String
    var redirectScheme: String
    var redirectHost: String
    var redirectPath: String
    var googleScopes: String
    var enableRemoteCatalog: Bool
    var enableRemoteWorkspace: Bool
    var enableSOPGateway: Bool
    var productionRequiresSignIn: Bool
    var enableAdminPreview: Bool
    var enableTestMockAuth: Bool
    var staffAdminEmails: [String]

    static let fallback = AppConfig(
        supabaseURL: "https://YOUR_PROJECT.supabase.co",
        supabaseAnonKey: "YOUR_SUPABASE_ANON_KEY",
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

    var redirectURL: URL {
        URL(string: "\(redirectScheme)://\(redirectHost)\(redirectPath)")!
    }

    var isConfigured: Bool {
        !supabaseURL.contains("YOUR_PROJECT") && !supabaseAnonKey.contains("YOUR_SUPABASE")
    }

    var authCallbackPrefix: String {
        "\(redirectScheme)://\(redirectHost)"
    }

    func grantsStaffAccess(email: String?) -> Bool {
        guard let email else { return false }
        return staffAdminEmails.map { $0.lowercased() }.contains(email.lowercased())
    }
}

struct AppRuntimeOptions: Hashable {
    var useMockAuthenticatedSession: Bool
    var enableAdminPreviewOnLaunch: Bool
    var loadSampleDataOnLaunch: Bool
    var forceGuestMode: Bool
    var preferEphemeralAuthSession: Bool
    var baseDirectoryOverride: URL?

    var showsDemoControls: Bool {
        useMockAuthenticatedSession || enableAdminPreviewOnLaunch || loadSampleDataOnLaunch || forceGuestMode
    }

    static func current(processInfo: ProcessInfo = .processInfo) -> AppRuntimeOptions {
        let args = Set(processInfo.arguments)
        let env = processInfo.environment
        let baseDirectoryOverride = env["ADMITPATH_BASE_DIRECTORY"].flatMap { URL(fileURLWithPath: $0, isDirectory: true) }

        return AppRuntimeOptions(
            useMockAuthenticatedSession: args.contains("-AdmitPathMockAuthenticated"),
            enableAdminPreviewOnLaunch: args.contains("-AdmitPathAdminPreview"),
            loadSampleDataOnLaunch: args.contains("-AdmitPathLoadSampleData"),
            forceGuestMode: args.contains("-AdmitPathGuestMode"),
            preferEphemeralAuthSession: args.contains("-AdmitPathEphemeralAuth"),
            baseDirectoryOverride: baseDirectoryOverride
        )
    }
}

enum AppConfigLoader {
    static var bundledResourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    static func load(bundle: Bundle = bundledResourceBundle) -> AppConfig {
        guard let url = bundle.url(forResource: "AppConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? FormatterFactory.makeJSONDecoder().decode(AppConfig.self, from: data) else {
            return .fallback
        }
        return config
    }
}
