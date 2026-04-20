import Foundation
import Testing
#if canImport(AdmitPathLogic)
@testable import AdmitPathLogic
#elseif canImport(AdmitPath)
@testable import AdmitPath
#endif

struct DemoDataLoaderTests {
    @Test
    func bundledSeedDataLoadsAndMeetsMinimumCounts() throws {
        let loader = DemoDataLoader(bundle: DemoDataLoader.bundledResourceBundle)
        let catalog = try loader.loadCatalog()

        #expect(catalog.universities.count >= 18)
        #expect(catalog.programs.count >= 36)
        #expect(catalog.requirements.count >= 36)
        #expect(catalog.deadlines.count >= 72)
        #expect(catalog.scholarships.count >= 18)
        #expect(catalog.peerProfiles.count >= 6)
        #expect(catalog.peerPosts.count >= 6)
        #expect(catalog.peerArtifacts.count >= 4)
        #expect(!catalog.sampleApplications.isEmpty)
        #expect(!catalog.sampleTasks.isEmpty)
    }

    @Test
    func flexibleDateDecoderSupportsPlainDateAndIsoStrings() throws {
        let decoder = FormatterFactory.makeJSONDecoder()
        let payload = """
        {
          "createdAt": "2027-01-05",
          "updatedAt": "2027-01-05T10:15:30Z"
        }
        """.data(using: .utf8)!

        struct DatePair: Decodable {
            let createdAt: Date
            let updatedAt: Date
        }

        let decoded = try decoder.decode(DatePair.self, from: payload)
        #expect(Calendar.current.component(.year, from: decoded.createdAt) == 2027)
        #expect(Calendar.current.component(.year, from: decoded.updatedAt) == 2027)
    }
}
