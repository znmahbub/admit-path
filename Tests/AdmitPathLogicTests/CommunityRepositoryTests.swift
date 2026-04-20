import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct CommunityRepositoryTests {
    @Test
    func relevantArtifactsPreferVerifiedContentAndReportFlowPersists() throws {
        let catalog = try DemoDataLoader(bundle: DemoDataLoader.bundledResourceBundle).loadCatalog()
        let repository = CommunityRepository(catalog: catalog)
        var state = DemoState.empty

        let artifacts = repository.allArtifacts()
        let first = try #require(artifacts.first)
        #expect(first.verificationStatus != .unverified)

        let postID = try #require(catalog.peerPosts.first?.id)
        repository.toggleBookmark(postID: postID, in: &state)
        repository.report(postID: postID, reason: "Needs review", in: &state)

        #expect(state.bookmarkedPostIDs.contains(postID))
        #expect(state.reports.count == 1)
        #expect(state.reports.first?.status == .underReview)
    }

    @Test
    func feedRankingAndGroupsPrioritizeRelevantTrustedContent() throws {
        let catalog = try DemoDataLoader(bundle: DemoDataLoader.bundledResourceBundle).loadCatalog()
        let repository = CommunityRepository(catalog: catalog)
        let profile = StudentProfile(
            id: "student_feed",
            fullName: "Feed User",
            nationality: "Bangladesh",
            currentCountry: "Bangladesh",
            targetIntake: "Fall 2027",
            degreeLevel: .undergrad,
            subjectArea: "Computer Science",
            secondaryResultPercent: 92,
            gpaValue: 0,
            gpaScale: 4.0,
            englishTestType: .ielts,
            englishTestScore: 7.5,
            workExperienceYears: 0,
            scholarshipNeeded: true,
            annualBudgetUSD: 30000,
            tuitionBudgetUSD: 22000,
            preferredCountries: ["United States", "Canada"],
            onboardingComplete: true
        )

        let feed = repository.feed(for: profile, shortlistProgramIDs: [])
        let first = try #require(feed.first)
        #expect(feed.isEmpty == false)
        #expect(first.ranking.relevanceScore >= 1)
        #expect(first.trustBadge != nil)

        let groups = repository.groups(for: profile)
        #expect(groups.contains(where: { $0.kind == .country && $0.title == "United States Applicants" }))
        #expect(groups.contains(where: { $0.kind == .major && $0.title.contains("Computer Science") }))
    }
}
