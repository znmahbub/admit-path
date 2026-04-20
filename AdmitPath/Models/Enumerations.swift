import Foundation

enum DegreeLevel: String, Codable, CaseIterable, Identifiable {
    case undergrad = "Undergraduate"
    case masters = "Master's"

    var id: String { rawValue }
}

enum SecondaryCurriculum: String, Codable, CaseIterable, Identifiable {
    case bangladeshHSC = "Bangladesh HSC"
    case aLevels = "A Levels"
    case ib = "IB"
    case other = "Other"

    var id: String { rawValue }
}

enum EnglishTestType: String, Codable, CaseIterable, Identifiable {
    case ielts = "IELTS"
    case toefl = "TOEFL"
    case duolingo = "Duolingo"
    case none = "None"

    var id: String { rawValue }
}

enum FitBand: String, Codable, CaseIterable, Identifiable {
    case realistic = "Realistic"
    case target = "Target"
    case ambitious = "Ambitious"

    var id: String { rawValue }

    static let strongFit = FitBand.realistic
    static let stretch = FitBand.ambitious
}

enum ApplicationStatus: String, Codable, CaseIterable, Identifiable, Comparable {
    case shortlisted = "Shortlisted"
    case researching = "Researching"
    case preparingDocs = "Preparing Docs"
    case readyToApply = "Ready to Apply"
    case submitted = "Submitted"
    case interview = "Interview"
    case decisionReceived = "Decision Received"

    var id: String { rawValue }

    private var sortIndex: Int {
        switch self {
        case .shortlisted: 0
        case .researching: 1
        case .preparingDocs: 2
        case .readyToApply: 3
        case .submitted: 4
        case .interview: 5
        case .decisionReceived: 6
        }
    }

    static func < (lhs: ApplicationStatus, rhs: ApplicationStatus) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

enum ApplicationTaskType: String, Codable, CaseIterable, Identifiable {
    case requirementsReview = "Requirements Review"
    case transcript = "Transcript"
    case cv = "CV"
    case sop = "SOP"
    case scholarshipEssay = "Scholarship Essay"
    case lor = "LOR"
    case passport = "Passport"
    case englishTest = "English Test"
    case financialProof = "Financial Proof"
    case portfolio = "Portfolio"
    case applicationForm = "Application Form"
    case applicationFee = "Application Fee"
    case deposit = "Deposit"
    case visa = "Visa"
    case interviewPrep = "Interview Prep"
    case submit = "Submit"
    case custom = "Custom"

    var id: String { rawValue }
}

enum ScholarshipCoverageType: String, Codable, CaseIterable, Identifiable {
    case fullTuition = "Full Tuition"
    case partialTuition = "Partial Tuition"
    case tuitionAndStipend = "Tuition and Stipend"
    case entranceAward = "Entrance Award"

    var id: String { rawValue }
}

enum ScholarshipMatchLevel: String, Codable, CaseIterable, Identifiable {
    case likelyEligible = "Likely Eligible"
    case possible = "Possible"
    case unlikely = "Unlikely"

    var id: String { rawValue }
}

enum SOPRewriteAction: String, CaseIterable, Identifiable {
    case shorter = "Make shorter"
    case moreFormal = "Make more formal"
    case academics = "Emphasize academics"
    case careerGoals = "Emphasize career goals"

    var id: String { rawValue }
}

enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case sop = "SOP"
    case cv = "CV"
    case lor = "LORs"
    case transcript = "Transcript"
    case englishScores = "English Scores"
    case passport = "Passport"
    case financialDocuments = "Financial Documents"
    case scholarshipEssay = "Scholarship Essay"
    case portfolio = "Portfolio"

    var id: String { rawValue }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today = "Today"
    case discover = "Discover"
    case community = "Community"
    case apply = "Apply"
    case funding = "Funding"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: return "sun.max.fill"
        case .discover: return "sparkles"
        case .community: return "person.3.fill"
        case .apply: return "checklist"
        case .funding: return "banknote.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .today: return "Execution, urgency, and momentum."
        case .discover: return "Programs, fit, and compare."
        case .community: return "Feed, groups, and trusted peers."
        case .apply: return "Requirements, essays, and deadlines."
        case .funding: return "Costs, scholarships, and affordability."
        }
    }
}

enum CommunityPostKind: String, Codable, CaseIterable, Identifiable {
    case question = "Question"
    case admitStory = "Admit Story"
    case interviewNotes = "Interview Notes"
    case scholarshipAdvice = "Scholarship Advice"

    var id: String { rawValue }
}

enum PeerRole: String, Codable, CaseIterable, Identifiable {
    case applicant = "Applicant"
    case student = "Current Student"
    case admit = "Admit"
    case alumni = "Alumni"

    var id: String { rawValue }
}

enum VerificationStatus: String, Codable, CaseIterable, Identifiable {
    case unverified = "Unverified"
    case verifiedStudent = "Verified Student"
    case verifiedAdmit = "Verified Admit"
    case verifiedAlumni = "Verified Alumni"

    var id: String { rawValue }
}

enum ModerationStatus: String, Codable, CaseIterable, Identifiable {
    case clear = "Clear"
    case underReview = "Under Review"
    case limited = "Limited"

    var id: String { rawValue }
}

enum PeerArtifactKind: String, Codable, CaseIterable, Identifiable {
    case sopSample = "SOP Sample"
    case scholarshipEssay = "Scholarship Essay"
    case timeline = "Decision Timeline"
    case interviewDebrief = "Interview Debrief"

    var id: String { rawValue }
}

enum PlannerMilestoneType: String, Codable, CaseIterable, Identifiable {
    case applicationDeadline = "Application Deadline"
    case scholarshipDeadline = "Scholarship Deadline"
    case depositDeadline = "Deposit Deadline"
    case interviewWindow = "Interview Window"
    case visaPrep = "Visa Prep"
    case testBooking = "Test Booking"
    case recommender = "Recommender"
    case documentTask = "Document Task"
    case userAdded = "User Added"

    var id: String { rawValue }
}

enum PlannerSource: String, Codable, CaseIterable, Identifiable {
    case catalog = "Catalog"
    case autoGenerated = "Auto Generated"
    case user = "User"

    var id: String { rawValue }
}

enum SOPProjectMode: String, Codable, CaseIterable, Identifiable {
    case master = "Master SOP"
    case programSpecific = "Program-Specific SOP"
    case scholarship = "Scholarship Essay"

    var id: String { rawValue }
}

enum SOPCritiqueFlagType: String, Codable, CaseIterable, Identifiable {
    case genericEvidence = "Needs Stronger Evidence"
    case repetitive = "Repetition"
    case lengthWarning = "Length Warning"
    case goalClarity = "Goal Clarity"

    var id: String { rawValue }
}
