import Foundation

struct ExploreViewModel {
    var filters: MatchFilters

    var availableCountries: [String] { AppConstants.supportedCountries }
    var availableSubjects: [String] { AppConstants.supportedSubjects }
    var availableDegreeLevels: [DegreeLevel] { DegreeLevel.allCases }
}

typealias MatchesViewModel = ExploreViewModel
