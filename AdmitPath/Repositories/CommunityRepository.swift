import Foundation

struct CommunityRepository {
    let catalog: CatalogData

    func allProfiles() -> [PeerProfile] {
        catalog.peerProfiles.sorted { $0.reputationScore > $1.reputationScore }
    }

    func allPosts() -> [PeerPost] {
        catalog.peerPosts
            .filter { $0.moderationStatus != .limited }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func allArtifacts() -> [PeerArtifact] {
        catalog.peerArtifacts
            .filter { $0.moderationStatus == .clear }
            .sorted { lhs, rhs in
                if lhs.verificationStatus != rhs.verificationStatus {
                    return rank(of: lhs.verificationStatus) > rank(of: rhs.verificationStatus)
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    func replies(for postID: String) -> [PeerReply] {
        catalog.peerReplies
            .filter { $0.postID == postID && $0.moderationStatus != .limited }
            .sorted { lhs, rhs in
                if lhs.isAcceptedAnswer != rhs.isAcceptedAnswer {
                    return lhs.isAcceptedAnswer && !rhs.isAcceptedAnswer
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func profile(id: String) -> PeerProfile? {
        catalog.peerProfiles.first { $0.id == id }
    }

    func relevantPosts(
        country: String? = nil,
        subjectArea: String? = nil,
        degreeLevel: DegreeLevel? = nil,
        programID: String? = nil
    ) -> [PeerPost] {
        allPosts().filter { post in
            if let country, post.country != country { return false }
            if let subjectArea, post.subjectArea.caseInsensitiveCompare(subjectArea) != .orderedSame { return false }
            if let degreeLevel, post.degreeLevel != degreeLevel { return false }
            if let programID, let postProgramID = post.programID, postProgramID != programID { return false }
            return true
        }
    }

    func relevantArtifacts(
        country: String? = nil,
        subjectArea: String? = nil,
        degreeLevel: DegreeLevel? = nil,
        programID: String? = nil
    ) -> [PeerArtifact] {
        allArtifacts().filter { artifact in
            if let country, artifact.country != country { return false }
            if let subjectArea, artifact.subjectArea.caseInsensitiveCompare(subjectArea) != .orderedSame { return false }
            if let degreeLevel, artifact.degreeLevel != degreeLevel { return false }
            if let programID, let artifactProgramID = artifact.programID, artifactProgramID != programID { return false }
            return true
        }
    }

    func toggleBookmark(postID: String, in state: inout DemoState) {
        if state.bookmarkedPostIDs.contains(postID) {
            state.bookmarkedPostIDs.remove(postID)
        } else {
            state.bookmarkedPostIDs.insert(postID)
        }
    }

    func report(postID: String, reason: String, in state: inout DemoState) {
        state.reports.append(
            CommunityReport(
                id: "report_\(postID)_\(state.reports.count + 1)",
                postID: postID,
                reason: reason,
                createdAt: .now,
                status: .underReview
            )
        )
    }

    func feed(for profile: StudentProfile?, shortlistProgramIDs: [String]) -> [FeedPost] {
        allPosts()
            .map { post in
                let author = self.profile(id: post.authorID)
                let ranking = ranking(
                    for: post,
                    author: author,
                    profile: profile,
                    shortlistProgramIDs: shortlistProgramIDs
                )
                let trustBadge = trustBadge(for: author)
                return FeedPost(
                    post: post,
                    author: author,
                    ranking: ranking,
                    trustBadge: trustBadge,
                    attachments: [],
                    reactions: [
                        Reaction(id: "\(post.id)_like", emoji: "👍", count: max(post.upvoteCount, 0))
                    ]
                )
            }
            .sorted { lhs, rhs in
                if lhs.ranking.totalScore != rhs.ranking.totalScore {
                    return lhs.ranking.totalScore > rhs.ranking.totalScore
                }
                return lhs.post.createdAt > rhs.post.createdAt
            }
    }

    func groups(for profile: StudentProfile?) -> [CommunityGroup] {
        guard let profile else { return [] }

        var groups: [CommunityGroup] = profile.preferredCountries.map { country in
            CommunityGroup(
                id: "group_country_\(country.lowercased().replacingOccurrences(of: " ", with: "_"))",
                title: "\(country) Applicants",
                subtitle: "Admissions updates, deadlines, and peer insights for \(country).",
                kind: .country,
                memberCount: estimatedMemberCount(for: country),
                postCount: relevantPosts(country: country, degreeLevel: profile.degreeLevel).count,
                isRecommended: true
            )
        }

        groups.append(
            CommunityGroup(
                id: "group_major_\(profile.subjectArea.lowercased().replacingOccurrences(of: " ", with: "_"))",
                title: "\(profile.subjectArea) Circle",
                subtitle: "Peer advice, essays, and applications for your intended major.",
                kind: .major,
                memberCount: max(allPosts().filter { $0.subjectArea.caseInsensitiveCompare(profile.subjectArea) == .orderedSame }.count * 9, 18),
                postCount: relevantPosts(subjectArea: profile.subjectArea, degreeLevel: profile.degreeLevel).count,
                isRecommended: true
            )
        )
        groups.append(
            CommunityGroup(
                id: "group_intake_\(profile.targetIntake.lowercased().replacingOccurrences(of: " ", with: "_"))",
                title: "\(profile.targetIntake) Cohort",
                subtitle: "Students applying in the same cycle with similar timelines.",
                kind: .intake,
                memberCount: 120,
                postCount: max(allPosts().count / 3, 12),
                isRecommended: true
            )
        )
        groups.append(
            CommunityGroup(
                id: "group_funding",
                title: "Scholarships & Funding",
                subtitle: "Budget gaps, awards, and affordability planning for Bangladesh-first applicants.",
                kind: .funding,
                memberCount: 240,
                postCount: allPosts().filter { $0.kind == .scholarshipAdvice }.count,
                isRecommended: profile.scholarshipNeeded
            )
        )

        return groups
    }

    private func rank(of status: VerificationStatus) -> Int {
        switch status {
        case .unverified: 0
        case .verifiedStudent: 1
        case .verifiedAdmit: 2
        case .verifiedAlumni: 3
        }
    }

    private func ranking(
        for post: PeerPost,
        author: PeerProfile?,
        profile: StudentProfile?,
        shortlistProgramIDs: [String]
    ) -> FeedRankingContext {
        let relevanceScore = relevanceScore(for: post, profile: profile, shortlistProgramIDs: shortlistProgramIDs)
        let trustScore = max((author.map { rank(of: $0.verificationStatus) } ?? 0) * 2, 0)
        let engagementScore = min(post.upvoteCount / 5, 6)
        let freshnessScore = freshnessScore(for: post.createdAt)
        let totalScore = relevanceScore + trustScore + engagementScore + freshnessScore

        return FeedRankingContext(
            relevanceScore: relevanceScore,
            trustScore: trustScore,
            engagementScore: engagementScore,
            freshnessScore: freshnessScore,
            totalScore: totalScore
        )
    }

    private func relevanceScore(
        for post: PeerPost,
        profile: StudentProfile?,
        shortlistProgramIDs: [String]
    ) -> Int {
        guard let profile else { return 1 }
        var score = 1
        if profile.preferredCountries.contains(post.country) {
            score += 3
        }
        if post.subjectArea.caseInsensitiveCompare(profile.subjectArea) == .orderedSame {
            score += 3
        }
        if post.degreeLevel == profile.degreeLevel {
            score += 2
        }
        if let programID = post.programID, shortlistProgramIDs.contains(programID) {
            score += 4
        }
        if post.kind == .scholarshipAdvice, profile.scholarshipNeeded {
            score += 2
        }
        return score
    }

    private func freshnessScore(for date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        switch days {
        case ..<3:
            return 6
        case ..<7:
            return 4
        case ..<21:
            return 2
        default:
            return 1
        }
    }

    private func trustBadge(for author: PeerProfile?) -> String? {
        guard let author else { return nil }
        switch author.verificationStatus {
        case .unverified:
            return nil
        case .verifiedStudent, .verifiedAdmit, .verifiedAlumni:
            return author.verificationStatus.rawValue
        }
    }

    private func estimatedMemberCount(for country: String) -> Int {
        max(allPosts().filter { $0.country == country }.count * 12, 24)
    }
}
