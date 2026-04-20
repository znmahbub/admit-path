import Foundation

struct SOPGenerationService {
    let questions: [String] = [
        "What sparked your interest in this field?",
        "What academic background supports you?",
        "What practical experience supports your case?",
        "Why this country?",
        "Why this university or type of program?",
        "What are your short-term and long-term goals?"
    ]

    func makeAnswers(from text: [String]) -> [SOPQuestionAnswer] {
        zip(questions, text).enumerated().map { index, pair in
            SOPQuestionAnswer(
                id: "answer_\(index)",
                question: pair.0,
                answer: pair.1
            )
        }
    }

    func generateOutline(
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship? = nil,
        mode: SOPProjectMode = .master,
        answers: [SOPQuestionAnswer]
    ) -> [String] {
        let whyProgram = program.map { "Why \(shortProgramName($0.name)) at \($0.universityName)" } ?? "Why this program"
        switch mode {
        case .master:
            return [
                "Introduction: state your transition into \(profile.subjectArea.lowercased()) and the admissions cycle you are targeting.",
                "Academic readiness: connect your strongest evidence to the study track you are applying for.",
                "Practical evidence: highlight internships, projects, competitions, or work that show readiness.",
                "\(whyProgram): link curriculum, country, and employability to your stated goals.",
                "Career direction: explain near-term and long-term goals with Bangladesh-specific relevance.",
                "Closing: reinforce seriousness, fit, and readiness to contribute."
            ]
        case .programSpecific:
            return [
                "Opening hook tied to \(program?.universityName ?? "the program") and your field choice.",
                "Academic preparation matched to the course structure and requirement profile.",
                "Applied experience that makes the program a coherent next step.",
                "Specific program fit: modules, faculty direction, city, or pathway logic.",
                "Career outcomes: why this route makes sense economically and professionally.",
                "Closing with contribution, community, and readiness."
            ]
        case .scholarship:
            return [
                "Mission statement and why funding materially changes feasibility.",
                "Academic strength and evidence of discipline.",
                "Leadership, initiative, or impact examples.",
                "Why the degree and destination matter for your next stage.",
                "How the scholarship would change the decision set and future contribution.",
                "Closing with accountability and expected impact."
            ]
        }
    }

    func generateDraft(
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship? = nil,
        mode: SOPProjectMode = .master,
        answers: [SOPQuestionAnswer]
    ) -> String {
        let answerMap = Dictionary(uniqueKeysWithValues: answers.map { ($0.question, $0.answer) })
        let fieldInterest = answerMap[questions[0]]?.nonEmpty ?? "My interest grew from seeing how structured analysis can improve real decisions."
        let academicSupport = answerMap[questions[1]]?.nonEmpty ?? "My academic work strengthened my quantitative reasoning, writing discipline, and ability to learn complex material quickly."
        let practicalSupport = answerMap[questions[2]]?.nonEmpty ?? "My practical experiences taught me to connect analysis with execution and communicate recommendations clearly."
        let countryReason = answerMap[questions[3]]?.nonEmpty ?? "The destination offers a practical blend of academic rigor, mobility, and employability."
        let programReason = answerMap[questions[4]]?.nonEmpty
            ?? program.map { _ in "Its curriculum and applied structure are a strong fit for my background." }
            ?? "The program structure matches the way I want to learn."
        let careerGoals = answerMap[questions[5]]?.nonEmpty ?? "In the short term I want a role where I can apply structured evidence and judgment well; in the long term I want to build leadership that creates measurable value in Bangladesh and the wider region."

        switch mode {
        case .master, .programSpecific:
            let degreeSentence = profile.degreeLevel == .masters ? "a taught Master's" : "an undergraduate degree"
            return """
            I am applying for \(program?.name ?? degreeSentence) in \(profile.subjectArea) because I want formal training that turns my existing interest into a disciplined academic and professional foundation. \(fieldInterest) In that context, \(degreeSentence) is the appropriate next step for me.

            Academically, I bring evidence that I can handle rigorous study. \(academicSupport) \(academicSummary(for: profile)) I also completed an \(profile.englishTestType.rawValue) score of \(formatDecimal(profile.englishTestScore, digits: 1)), which supports my readiness to work effectively in an English-language academic environment.

            Beyond academics, \(practicalSupport) That practical evidence matters because I do not view graduate study as an abstract goal. I see it as part of a concrete progression from preparation to execution.

            I am particularly motivated by \(program?.name ?? "this program") at \(program?.universityName ?? "your institution") because \(programReason) \(countryReason) I value programs that combine structured theory, peer learning, and clear practical relevance, especially for international students making financially consequential decisions.

            \(careerGoals) Because financing study abroad matters materially for my decision, scholarship support and careful planning are central to how I assess fit, but they do not change the seriousness of my academic intent.

            For these reasons, I see this degree as the right platform for the next stage of my development. I would approach the program with seriousness, curiosity, and a clear sense of purpose, and I am ready to contribute fully to its academic community.
            """
        case .scholarship:
            return """
            I am seeking support from \(scholarship?.name ?? "this scholarship") because funding is not peripheral to my application decision; it is central to whether I can choose the strongest academic fit instead of the cheapest available option. \(fieldInterest)

            My academic preparation gives me a credible foundation for the study path I am pursuing. \(academicSupport) \(academicSummary(for: profile)) \(practicalSupport)

            The program I am targeting is compelling to me because \(programReason) \(countryReason) With scholarship support, I would be able to focus on extracting the most from the degree rather than treating cost as the binding constraint.

            \(careerGoals) That is why this scholarship matters: it would not simply reduce cost, it would widen the set of academically coherent choices available to me and strengthen my ability to convert study abroad into long-run value for my community.

            I would approach this support with accountability, discipline, and a clear sense of what it should enable. If selected, I would treat the scholarship as an obligation to perform well and translate the opportunity into measurable contribution.
            """
        }
    }

    func critique(
        draft: String,
        answers: [SOPQuestionAnswer],
        mode: SOPProjectMode
    ) -> [SOPCritiqueFlag] {
        var flags: [SOPCritiqueFlag] = []
        let trimmedAnswers = answers.map { $0.answer.trimmingCharacters(in: .whitespacesAndNewlines) }
        let wordCount = draft.split(whereSeparator: \.isWhitespace).count

        if trimmedAnswers.filter({ $0.count >= 40 }).count < 4 {
            flags.append(
                SOPCritiqueFlag(
                    id: "flag_evidence",
                    type: .genericEvidence,
                    message: "Several answers are still thin. Add concrete coursework, projects, or outcomes before treating this as final."
                )
            )
        }

        if wordCount < 260 || wordCount > 850 {
            flags.append(
                SOPCritiqueFlag(
                    id: "flag_length",
                    type: .lengthWarning,
                    message: "The current draft length may need adjustment for school-specific requirements."
                )
            )
        }

        if draft.lowercased().components(separatedBy: "i want").count > 3 {
            flags.append(
                SOPCritiqueFlag(
                    id: "flag_repetition",
                    type: .repetitive,
                    message: "The draft repeats similar intention phrases. Tighten wording and vary evidence."
                )
            )
        }

        if let goals = trimmedAnswers.last, goals.count < 35 {
            flags.append(
                SOPCritiqueFlag(
                    id: "flag_goals",
                    type: .goalClarity,
                    message: "The goals section is still vague. Add clearer short-run and long-run outcomes."
                )
            )
        }

        if mode == .scholarship && !draft.localizedCaseInsensitiveContains("fund") {
            flags.append(
                SOPCritiqueFlag(
                    id: "flag_scholarship",
                    type: .goalClarity,
                    message: "Scholarship essays should explain why funding changes feasibility, not only why the program is attractive."
                )
            )
        }

        return flags
    }

    func makeProject(
        existing: SOPProject?,
        title: String,
        mode: SOPProjectMode,
        profile: StudentProfile,
        program: Program?,
        scholarship: Scholarship?,
        answers: [SOPQuestionAnswer]
    ) -> SOPProject {
        let outline = generateOutline(profile: profile, program: program, scholarship: scholarship, mode: mode, answers: answers)
        let draft = generateDraft(profile: profile, program: program, scholarship: scholarship, mode: mode, answers: answers)
        let critiqueFlags = critique(draft: draft, answers: answers, mode: mode)
        let previousVersions = existing?.versions ?? []
        let nextVersionNumber = (previousVersions.last?.versionNumber ?? 0) + 1
        let version = SOPVersion(
            id: "\(existing?.id ?? "sop_project")_v\(nextVersionNumber)",
            versionNumber: nextVersionNumber,
            content: draft,
            createdAt: .now
        )

        return SOPProject(
            id: existing?.id ?? "sop_\(program?.id ?? scholarship?.id ?? mode.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))",
            programID: program?.id ?? existing?.programID,
            scholarshipID: scholarship?.id ?? existing?.scholarshipID,
            title: title,
            mode: mode,
            questionnaireAnswers: answers,
            generatedOutline: outline,
            generatedDraft: draft,
            critiqueFlags: critiqueFlags,
            versions: previousVersions + [version],
            updatedAt: .now
        )
    }

    func rewrite(draft: String, action: SOPRewriteAction) -> String {
        switch action {
        case .shorter:
            let sentences = draft.split(separator: ".").map(String.init).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            return sentences.prefix(6).joined(separator: ". ") + "."
        case .moreFormal:
            return draft
                .replacingOccurrences(of: "I want", with: "I seek")
                .replacingOccurrences(of: "I am particularly motivated by", with: "I am particularly compelled by")
                .replacingOccurrences(of: "the right platform", with: "the appropriate platform")
        case .academics:
            return "My academic preparation is central to this application. " + draft
        case .careerGoals:
            return "The professional trajectory enabled by this degree is central to my application. " + draft
        }
    }

    private func academicSummary(for profile: StudentProfile) -> String {
        if profile.degreeLevel == .undergrad {
            return "My strongest current academic signal is a \(formatDecimal(profile.secondaryResultPercent ?? 0, digits: 1))% outcome in \(profile.secondaryCurriculum.rawValue)."
        }
        return "My strongest current academic signal is a GPA of \(formatDecimal(profile.gpaValue, digits: 2))/\(formatDecimal(profile.gpaScale, digits: 1))."
    }

    private func shortProgramName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "MSc ", with: "")
            .replacingOccurrences(of: "BSc ", with: "")
            .replacingOccurrences(of: "BA ", with: "")
            .replacingOccurrences(of: "BEng ", with: "")
            .replacingOccurrences(of: "MPP ", with: "")
    }
}

private extension String {
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
