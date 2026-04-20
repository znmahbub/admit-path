import Foundation

struct MatchingService {
    private let affordabilityService = AffordabilityService()

    func rankedPrograms(
        profile: StudentProfile?,
        filters: MatchFilters,
        universities: [University],
        programs: [Program],
        requirements: [ProgramRequirement],
        deadlines: [ProgramDeadline],
        scholarships: [ScholarshipMatch]
    ) -> [ProgramMatch] {
        guard let profile else { return [] }

        let countryByUniversity = Dictionary(uniqueKeysWithValues: universities.map { ($0.id, $0.country) })
        let requirementsByProgram = Dictionary(uniqueKeysWithValues: requirements.map { ($0.programID, $0) })
        let deadlinesByProgram = Dictionary(grouping: deadlines, by: \.programID)
        let viableScholarships = scholarships.filter { $0.level != .unlikely }

        let matches = programs.map { program -> ProgramMatch in
            let requirement = requirementsByProgram[program.id]
            let nextDeadline = deadlinesByProgram[program.id]?
                .sorted(by: { $0.applicationDeadline < $1.applicationDeadline })
                .first(where: { $0.applicationDeadline >= Date() })
                ?? deadlinesByProgram[program.id]?.sorted(by: { $0.applicationDeadline < $1.applicationDeadline }).first
            let country = countryByUniversity[program.universityID] ?? "Unknown"

            let relevantScholarships = viableScholarships.filter { match in
                match.scholarship.destinationCountries.contains(country)
                    && match.scholarship.eligibleDegreeLevels.contains(program.degreeLevel)
                    && match.scholarship.eligibleSubjects.contains(where: { $0.caseInsensitiveCompare(program.subjectArea) == .orderedSame })
            }
            let scholarshipCount = relevantScholarships.count
            let academic = academicScore(profile: profile, requirement: requirement)
            let language = languageScore(profile: profile, requirement: requirement)
            let affordability = affordabilityScore(profile: profile, program: program)
            let countryFit = countryScore(profile: profile, country: country)
            let subject = subjectScore(profile: profile, program: program)
            let scholarship = scholarshipScore(profile: profile, scholarshipCount: scholarshipCount)
            let deadline = deadlineScore(nextDeadline)
            let total = [academic, language, affordability, countryFit, subject, scholarship, deadline].reduce(0, +)
            let affordabilityScenario = affordabilityService.scenario(
                for: profile,
                program: program,
                scholarships: relevantScholarships,
                country: country
            )
            let estimatedFundingGapUSD = affordabilityScenario.remainingGapUSD
            let fitReasonLedger = makeFitReasonLedger(
                profile: profile,
                program: program,
                country: country,
                requirement: requirement,
                scholarshipCount: scholarshipCount,
                scores: [
                    ("Academics", academic),
                    ("Language", language),
                    ("Affordability", affordability),
                    ("Destination", countryFit),
                    ("Subject", subject),
                    ("Scholarships", scholarship),
                    ("Deadline", deadline)
                ]
            )
            let confidence = confidence(
                requirement: requirement,
                nextDeadline: nextDeadline,
                scholarships: relevantScholarships,
                country: country
            )
            let netCostEstimateUSD = affordabilityScenario.netCostAfterScholarshipsUSD

            let band = fitBand(for: total)

            return ProgramMatch(
                program: program,
                country: country,
                requirement: requirement,
                nextDeadline: nextDeadline,
                score: total,
                fitBand: band,
                explanation: explanation(
                    for: profile,
                    program: program,
                    country: country,
                    band: band,
                    scholarshipCount: scholarshipCount,
                    score: total,
                    fundingGapUSD: estimatedFundingGapUSD,
                    fitReasonLedger: fitReasonLedger,
                    netCostEstimateUSD: netCostEstimateUSD
                ),
                scholarshipCount: scholarshipCount,
                estimatedFundingGapUSD: estimatedFundingGapUSD,
                affordabilitySummary: affordabilitySummary(program: program, fundingGapUSD: estimatedFundingGapUSD),
                fitReasonLedger: fitReasonLedger,
                confidence: confidence,
                netCostEstimateUSD: netCostEstimateUSD,
                sourceFreshness: program.dataFreshness,
                affordabilityScenario: affordabilityScenario
            )
        }

        return matches
            .filter { passesFilters(match: $0, filters: filters) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                let lhsDeadline = lhs.nextDeadline?.applicationDeadline ?? .distantFuture
                let rhsDeadline = rhs.nextDeadline?.applicationDeadline ?? .distantFuture
                return lhsDeadline < rhsDeadline
            }
    }

    func fitBand(for score: Int) -> FitBand {
        switch score {
        case 78...: .realistic
        case 58...77: .target
        default: .ambitious
        }
    }

    private func academicScore(profile: StudentProfile, requirement: ProgramRequirement?) -> Int {
        guard let requirement else { return 18 }

        if profile.degreeLevel == .undergrad {
            let threshold = (requirement.minSecondaryPercent ?? 80) / 100.0
            let diff = profile.normalizedAcademicStrength - threshold
            switch diff {
            case 0.08...: return 24
            case 0.04..<0.08: return 22
            case 0..<0.04: return 18
            case -0.03..<0: return 10
            default: return 3
            }
        }

        let requirementNormalized = requirement.minGPAValue / max(requirement.minGPAScale, 0.1)
        let diff = profile.normalizedAcademicStrength - requirementNormalized

        switch diff {
        case 0.15...: return 24
        case 0.08..<0.15: return 22
        case 0..<0.08: return 19
        case -0.05..<0: return 10
        default: return 3
        }
    }

    private func languageScore(profile: StudentProfile, requirement: ProgramRequirement?) -> Int {
        guard let requirement else { return 12 }
        let minScore: Double
        switch profile.englishTestType {
        case .ielts:
            minScore = requirement.ieltsMin ?? 6.0
        case .toefl:
            minScore = requirement.toeflMin ?? 80
        case .duolingo:
            minScore = requirement.duolingoMin ?? 110
        case .none:
            return 0
        }

        let diff = profile.englishTestScore - minScore
        switch diff {
        case 0.8...: return 18
        case 0.3..<0.8: return 16
        case 0..<0.3: return 13
        case -0.5..<0: return 6
        default: return 2
        }
    }

    private func affordabilityScore(profile: StudentProfile, program: Program) -> Int {
        let tuitionRatio = Double(program.tuitionUSD) / Double(max(profile.effectiveTuitionBudgetUSD, 1))
        let annualRatio = Double(program.totalCostOfAttendanceUSD) / Double(max(profile.effectiveAnnualBudgetUSD, 1))

        switch (tuitionRatio, annualRatio) {
        case (...0.9, ...0.9): return 20
        case (...1.0, ...1.0): return 17
        case (...1.12, ...1.12): return 12
        case (...1.25, ...1.25): return 7
        default: return 2
        }
    }

    private func countryScore(profile: StudentProfile, country: String) -> Int {
        guard profile.preferredCountries.isNotEmpty else { return 5 }
        return profile.preferredCountries.contains(country) ? 9 : 2
    }

    private func subjectScore(profile: StudentProfile, program: Program) -> Int {
        if profile.subjectArea.caseInsensitiveCompare(program.subjectArea) == .orderedSame {
            return 12
        }
        if profile.subjectArea.localizedCaseInsensitiveContains(program.subjectArea)
            || program.subjectArea.localizedCaseInsensitiveContains(profile.subjectArea) {
            return 8
        }
        return 3
    }

    private func scholarshipScore(profile: StudentProfile, scholarshipCount: Int) -> Int {
        if !profile.scholarshipNeeded { return 7 }
        if scholarshipCount > 1 { return 10 }
        if scholarshipCount == 1 { return 7 }
        return 2
    }

    private func deadlineScore(_ deadline: ProgramDeadline?) -> Int {
        guard let deadline else { return 2 }
        let days = Calendar.current.dateComponents([.day], from: .now, to: deadline.applicationDeadline).day ?? 365
        switch days {
        case 21...120: return 7
        case 7..<21: return 5
        case 0..<7: return 3
        default: return 4
        }
    }

    private func explanation(
        for profile: StudentProfile,
        program: Program,
        country: String,
        band: FitBand,
        scholarshipCount: Int,
        score: Int,
        fundingGapUSD: Int,
        fitReasonLedger: [FitReasonItem],
        netCostEstimateUSD: Int
    ) -> String {
        var fragments = ["\(band.rawValue) because your profile scores \(score)/100 across academics, language, affordability, and destination fit"]
        if profile.preferredCountries.contains(country) {
            fragments.append("the destination is inside your stated target-country set")
        }
        if fundingGapUSD == 0 {
            fragments.append("the current cost profile fits within your stated annual budget")
        } else {
            fragments.append("you would need roughly \(formatCurrency(fundingGapUSD)) in additional annual funding")
        }
        if scholarshipCount > 0 {
            fragments.append("\(scholarshipCount) scholarship path\(scholarshipCount == 1 ? "" : "s") appear relevant")
        }
        if !program.bangladeshFitNote.isEmpty {
            fragments.append(program.bangladeshFitNote)
        }
        let ledgerSummary = fitReasonLedger
            .prefix(3)
            .map { "\($0.label.lowercased()) \($0.score)" }
            .joined(separator: ", ")
        fragments.append("net cost estimate is \(formatCurrency(netCostEstimateUSD))")
        return fragments.joined(separator: ", ") + ". Fit ledger: \(ledgerSummary)."
    }

    private func affordabilitySummary(program: Program, fundingGapUSD: Int) -> String {
        if fundingGapUSD == 0 {
            return "Within stated annual budget"
        }
        return "Needs \(formatCurrency(fundingGapUSD)) more in annual funding"
    }

    private func passesFilters(match: ProgramMatch, filters: MatchFilters) -> Bool {
        if let country = filters.country, match.country != country {
            return false
        }
        if let subjectArea = filters.subjectArea, match.program.subjectArea.caseInsensitiveCompare(subjectArea) != .orderedSame {
            return false
        }
        if let degreeLevel = filters.degreeLevel, match.program.degreeLevel != degreeLevel {
            return false
        }
        if let maxCost = filters.maxCostOfAttendance, match.program.totalCostOfAttendanceUSD > maxCost {
            return false
        }
        if filters.scholarshipOnly, !match.program.scholarshipAvailable && match.scholarshipCount == 0 {
            return false
        }
        if let fitBand = filters.fitBand, match.fitBand != fitBand {
            return false
        }
        return true
    }

    private func makeFitReasonLedger(
        profile: StudentProfile,
        program: Program,
        country: String,
        requirement: ProgramRequirement?,
        scholarshipCount: Int,
        scores: [(String, Int)]
    ) -> [FitReasonItem] {
        scores.map { label, score in
            FitReasonItem(
                id: "\(program.id)_\(label.lowercased())",
                label: label,
                detail: detail(
                    for: label,
                    profile: profile,
                    program: program,
                    country: country,
                    requirement: requirement,
                    scholarshipCount: scholarshipCount,
                    score: score
                ),
                score: score
            )
        }
    }

    private func detail(
        for label: String,
        profile: StudentProfile,
        program: Program,
        country: String,
        requirement: ProgramRequirement?,
        scholarshipCount: Int,
        score: Int
    ) -> String {
        switch label {
        case "Academics":
            if profile.degreeLevel == .undergrad {
                return "Secondary score is \(formatDecimal(profile.secondaryResultPercent ?? 0, digits: 1))% against published thresholds."
            }
            return "Academic profile is assessed against GPA requirements for \(program.name)."
        case "Language":
            return "English test score is evaluated against the listed minimum requirement."
        case "Affordability":
            return "Tuition and total attendance cost are compared to your stated family and annual budgets."
        case "Destination":
            return profile.preferredCountries.contains(country)
                ? "Country is inside your preferred destination set."
                : "Country is outside your current preferred destination set."
        case "Subject":
            return "Subject alignment compares your intended major to \(program.subjectArea)."
        case "Scholarships":
            return scholarshipCount == 0
                ? "No strong scholarship paths are currently linked to this result."
                : "\(scholarshipCount) relevant scholarship path\(scholarshipCount == 1 ? "" : "s") support this result."
        case "Deadline":
            return "Upcoming deadline timing affects urgency and practical application fit."
        default:
            return "Score contribution: \(score)."
        }
    }

    private func confidence(
        requirement: ProgramRequirement?,
        nextDeadline: ProgramDeadline?,
        scholarships: [ScholarshipMatch],
        country: String
    ) -> MatchConfidence {
        let signalCount = [
            requirement != nil,
            nextDeadline != nil,
            !scholarships.isEmpty,
            country != "Unknown"
        ].filter { $0 }.count

        switch signalCount {
        case 4: return MatchConfidence.high
        case 2...3: return MatchConfidence.medium
        default: return MatchConfidence.low
        }
    }
}
