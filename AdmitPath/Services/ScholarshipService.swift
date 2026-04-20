import Foundation

struct ScholarshipService {
    func rankedScholarships(profile: StudentProfile?, scholarships: [Scholarship]) -> [ScholarshipMatch] {
        guard let profile else { return [] }

        return scholarships.map { scholarship in
            let nationalityMatch = scholarship.eligibleNationalities.contains(profile.nationality)
            let destinationMatch = scholarship.destinationCountries.contains(where: profile.preferredCountries.contains)
            let degreeMatch = scholarship.eligibleDegreeLevels.contains(profile.degreeLevel)
            let subjectMatch = scholarship.eligibleSubjects.contains(where: {
                $0.caseInsensitiveCompare(profile.subjectArea) == .orderedSame
            })
            let academicMatch: Bool = {
                if profile.degreeLevel == .undergrad {
                    return scholarship.minSecondaryPercent.map { (profile.secondaryResultPercent ?? 0) >= $0 } ?? true
                }
                return scholarship.minGPAValue.map { profile.gpaValue >= $0 } ?? true
            }()
            let needMatch = !scholarship.needBased || profile.scholarshipNeeded

            var score = 0
            score += nationalityMatch ? 20 : 0
            score += destinationMatch ? 20 : 0
            score += degreeMatch ? 15 : 0
            score += subjectMatch ? 20 : 0
            score += academicMatch ? 15 : 0
            score += needMatch ? 10 : 0

            let level: ScholarshipMatchLevel
            if nationalityMatch && destinationMatch && degreeMatch && subjectMatch && academicMatch && score >= 75 {
                level = .likelyEligible
            } else if score >= 45 {
                level = .possible
            } else {
                level = .unlikely
            }

            return ScholarshipMatch(
                scholarship: scholarship,
                level: level,
                reason: buildReason(
                    scholarship: scholarship,
                    nationalityMatch: nationalityMatch,
                    destinationMatch: destinationMatch,
                    degreeMatch: degreeMatch,
                    subjectMatch: subjectMatch,
                    academicMatch: academicMatch,
                    needMatch: needMatch,
                    profile: profile
                ),
                projectedGapUSD: max(profile.effectiveTuitionBudgetUSD - (scholarship.maxAmountUSD ?? 0), 0)
            )
        }
        .sorted { lhs, rhs in
            if lhs.level != rhs.level {
                return rank(of: lhs.level) < rank(of: rhs.level)
            }
            if (lhs.scholarship.maxAmountUSD ?? 0) != (rhs.scholarship.maxAmountUSD ?? 0) {
                return (lhs.scholarship.maxAmountUSD ?? 0) > (rhs.scholarship.maxAmountUSD ?? 0)
            }
            return lhs.scholarship.deadline < rhs.scholarship.deadline
        }
    }

    private func buildReason(
        scholarship: Scholarship,
        nationalityMatch: Bool,
        destinationMatch: Bool,
        degreeMatch: Bool,
        subjectMatch: Bool,
        academicMatch: Bool,
        needMatch: Bool,
        profile: StudentProfile
    ) -> String {
        var reasons: [String] = []
        if nationalityMatch { reasons.append("Bangladeshi applicants are eligible") }
        if destinationMatch { reasons.append("the destination overlaps with your current country targets") }
        if subjectMatch { reasons.append("the subject area is aligned") }
        if degreeMatch { reasons.append("the degree track matches") }
        if scholarship.minGPAValue != nil && academicMatch {
            reasons.append("your academic profile clears the stated minimum")
        }
        if scholarship.minSecondaryPercent != nil && academicMatch {
            reasons.append("your secondary results appear competitive for the scholarship")
        }
        if scholarship.needBased && needMatch {
            reasons.append("it rewards demonstrated financial need")
        }
        if !degreeMatch {
            reasons.append("the degree level may not align cleanly")
        }
        if scholarship.essayPromptHint.isNotEmpty {
            reasons.append("there is a known essay angle to plan early")
        }
        return reasons.isEmpty ? "Limited fit based on the current profile fields." : reasons.joined(separator: ", ") + "."
    }

    private func rank(of level: ScholarshipMatchLevel) -> Int {
        switch level {
        case .likelyEligible: 0
        case .possible: 1
        case .unlikely: 2
        }
    }
}
