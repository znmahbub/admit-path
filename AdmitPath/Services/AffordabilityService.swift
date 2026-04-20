import Foundation

struct AffordabilityService {
    func scenario(
        for profile: StudentProfile,
        program: Program,
        scholarships: [ScholarshipMatch],
        country: String
    ) -> AffordabilityScenario {
        let familyPlan = profile.resolvedFamilyFundingPlan
        let familyContributionUSD = familyPlan.totalAvailableUSD
        let scholarshipSupportUSD = scholarships
            .filter { $0.level != .unlikely }
            .compactMap(\.scholarship.maxAmountUSD)
            .reduce(0, +)
        let netCostAfterScholarshipsUSD = max(program.totalCostOfAttendanceUSD - scholarshipSupportUSD, 0)
        let remainingGapUSD = max(netCostAfterScholarshipsUSD - familyContributionUSD, 0)
        let requiresLoanSupport = remainingGapUSD > 0 || familyPlan.needsLoanSupport

        return AffordabilityScenario(
            id: "affordability_\(program.id)",
            country: country,
            totalCostUSD: program.totalCostOfAttendanceUSD,
            familyContributionUSD: familyContributionUSD,
            scholarshipSupportUSD: scholarshipSupportUSD,
            netCostAfterScholarshipsUSD: netCostAfterScholarshipsUSD,
            remainingGapUSD: remainingGapUSD,
            requiresLoanSupport: requiresLoanSupport,
            netCostSummary: summary(
                netCostAfterScholarshipsUSD: netCostAfterScholarshipsUSD,
                remainingGapUSD: remainingGapUSD,
                requiresLoanSupport: requiresLoanSupport
            )
        )
    }

    private func summary(
        netCostAfterScholarshipsUSD: Int,
        remainingGapUSD: Int,
        requiresLoanSupport: Bool
    ) -> String {
        if remainingGapUSD == 0 && !requiresLoanSupport {
            return "Net cost \(formatCurrency(netCostAfterScholarshipsUSD)) is currently covered by family funding and scholarships."
        }

        if remainingGapUSD == 0 {
            return "Net cost \(formatCurrency(netCostAfterScholarshipsUSD)) is covered, but the plan still assumes loan or external funding support."
        }

        return "Net cost after scholarships is \(formatCurrency(netCostAfterScholarshipsUSD)) with a remaining gap of \(formatCurrency(remainingGapUSD))."
    }
}
