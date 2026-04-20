import Foundation

enum SessionRole: String, Codable, Hashable {
    case guest
    case student
    case staff
    case adminPreview
}

enum SyncStatus: Equatable {
    case localGuest
    case restoring
    case syncing
    case synced(Date)
    case requiresNetwork(String)
    case failed(String)

    var canWriteCloud: Bool {
        switch self {
        case .localGuest, .synced:
            return true
        case .restoring, .syncing, .requiresNetwork, .failed:
            return false
        }
    }

    var summary: String {
        switch self {
        case .localGuest:
            return "Stored locally on this device."
        case .restoring:
            return "Restoring your cloud workspace."
        case .syncing:
            return "Syncing your latest changes."
        case .synced(let date):
            return "Cloud sync complete • \(formatDate(date))"
        case .requiresNetwork(let message), .failed(let message):
            return message
        }
    }
}

struct AuthUser: Codable, Hashable, Identifiable {
    var id: String
    var email: String
    var displayName: String
    var avatarURL: String?
    var provider: String
}

enum UserProfileRole: String, Codable, Hashable {
    case student
    case staff
}

struct RemoteUserProfile: Codable, Hashable, Identifiable {
    var id: String
    var email: String
    var displayName: String
    var avatarURL: String?
    var role: UserProfileRole
    var verificationStatus: VerificationStatus
    var googleProvider: String
}

struct AuthSession: Codable, Hashable {
    var accessToken: String
    var refreshToken: String
    var tokenType: String
    var expiresAt: Date
    var providerToken: String?
    var providerRefreshToken: String?
    var user: AuthUser

    var isExpired: Bool {
        expiresAt <= Date().addingTimeInterval(60)
    }
}

enum AuthState: Equatable {
    case guest
    case authenticating
    case authenticated(AuthSession)
    case adminPreview

    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }

    var isAdminPreview: Bool {
        if case .adminPreview = self {
            return true
        }
        return false
    }
}

enum ProtectedFeature: String, Hashable {
    case saveProgram = "save programs"
    case comparePrograms = "compare programs"
    case applications = "create applications"
    case sopProjects = "save SOP drafts"
    case bookmarks = "bookmark peer posts"
    case reports = "report peer content"
    case communityPost = "post in the community"
    case communityReply = "reply in the community"
    case communityArtifact = "share verified artifacts"
}

struct AuthPrompt: Identifiable, Hashable {
    var id = UUID()
    var feature: ProtectedFeature

    var title: String {
        "Sign in with Google"
    }

    var message: String {
        "Use Google to \(feature.rawValue), sync your workspace, and keep progress across devices."
    }
}
