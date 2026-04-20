import Foundation

enum DemoDataLoaderError: LocalizedError {
    case missingResource(String)
    case invalidCatalog([String])

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Could not find seed resource \(name)."
        case .invalidCatalog(let issues):
            return "Bundled catalog validation failed: \(issues.joined(separator: " | "))"
        }
    }
}

struct DemoDataLoader {
    private let bundle: Bundle

    static var bundledResourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    init(bundle: Bundle = DemoDataLoader.bundledResourceBundle) {
        self.bundle = bundle
    }

    func loadCatalog() throws -> CatalogData {
        let catalog = CatalogData(
            universities: try decode("universities", as: [University].self),
            programs: try decode("programs", as: [Program].self),
            requirements: try decode("program_requirements", as: [ProgramRequirement].self),
            deadlines: try decode("program_deadlines", as: [ProgramDeadline].self),
            scholarships: try decode("scholarships", as: [Scholarship].self),
            peerProfiles: try decode("peer_profiles", as: [PeerProfile].self),
            peerPosts: try decode("peer_posts", as: [PeerPost].self),
            peerReplies: try decode("peer_replies", as: [PeerReply].self),
            peerArtifacts: try decode("peer_artifacts", as: [PeerArtifact].self),
            sampleProfile: try decode("sample_profile", as: StudentProfile.self),
            sampleApplications: try decode("sample_applications", as: [ApplicationRecord].self),
            sampleTasks: try decode("sample_tasks", as: [ApplicationTask].self)
        )
        let issues = validate(catalog)
        if issues.isNotEmpty {
            throw DemoDataLoaderError.invalidCatalog(issues)
        }
        return catalog
    }

    private func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw DemoDataLoaderError.missingResource(name)
        }
        let data = try Data(contentsOf: url)
        return try FormatterFactory.makeJSONDecoder().decode(T.self, from: data)
    }

    private func validate(_ catalog: CatalogData) -> [String] {
        var issues: [String] = []
        let minimums: [(String, Int, Int)] = [
            ("universities", catalog.universities.count, 18),
            ("programs", catalog.programs.count, 36),
            ("requirements", catalog.requirements.count, 36),
            ("deadlines", catalog.deadlines.count, 72),
            ("scholarships", catalog.scholarships.count, 18),
            ("peer profiles", catalog.peerProfiles.count, 6),
            ("peer posts", catalog.peerPosts.count, 6),
            ("peer artifacts", catalog.peerArtifacts.count, 4),
            ("sample applications", catalog.sampleApplications.count, 1),
            ("sample tasks", catalog.sampleTasks.count, 1)
        ]

        for (label, actual, expectedMinimum) in minimums where actual < expectedMinimum {
            issues.append("\(label) expected at least \(expectedMinimum) records but found \(actual)")
        }

        let universityIDs = Set(catalog.universities.map(\.id))
        let programIDs = Set(catalog.programs.map(\.id))
        let peerProfileIDs = Set(catalog.peerProfiles.map(\.id))

        for program in catalog.programs where !universityIDs.contains(program.universityID) {
            issues.append("program \(program.id) references missing university \(program.universityID)")
        }

        for requirement in catalog.requirements where !programIDs.contains(requirement.programID) {
            issues.append("requirement \(requirement.id) references missing program \(requirement.programID)")
        }

        for deadline in catalog.deadlines where !programIDs.contains(deadline.programID) {
            issues.append("deadline \(deadline.id) references missing program \(deadline.programID)")
        }

        for application in catalog.sampleApplications where !programIDs.contains(application.programID) {
            issues.append("sample application \(application.id) references missing program \(application.programID)")
        }

        for post in catalog.peerPosts where !peerProfileIDs.contains(post.authorID) {
            issues.append("peer post \(post.id) references missing author \(post.authorID)")
        }

        for reply in catalog.peerReplies where !peerProfileIDs.contains(reply.authorID) {
            issues.append("peer reply \(reply.id) references missing author \(reply.authorID)")
        }

        for artifact in catalog.peerArtifacts where !peerProfileIDs.contains(artifact.authorID) {
            issues.append("peer artifact \(artifact.id) references missing author \(artifact.authorID)")
        }

        return issues
    }
}
