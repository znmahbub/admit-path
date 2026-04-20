import SwiftUI

struct OnboardingContainerView: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: OnboardingViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(profile: appState.profile, environment: appState.environment))
    }

    var body: some View {
        NavigationStack {
            AppCanvas {
                if !viewModel.hasStarted {
                    welcomeView
                } else {
                    onboardingView
                }
            }
            .appInlineNavigationTitle()
        }
    }

    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
            HeroCard(
                eyebrow: "Bangladesh-first beta",
                title: "A serious admissions workspace for undergraduate applicants planning abroad",
                subtitle: "AdmitPath combines realistic shortlisting, application planning, essay support, scholarship tracking, affordability planning, and peer signals in one cloud-backed workspace."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "Multi-country", systemImage: "globe.europe.africa.fill", tint: .white)
                    SummaryPill(title: "Synced", systemImage: "arrow.triangle.2.circlepath.circle.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("What this build proves", subtitle: "Execution first, not consultant theater.")
                TimelineRow(
                    title: "Shortlist realistic programs",
                    subtitle: "Transparent fit bands use academics, budget, destination, subject, and scholarship context.",
                    systemImage: "sparkles",
                    tint: AppTheme.primary,
                    trailing: nil
                )
                TimelineRow(
                    title: "Track execution",
                    subtitle: "Turn a match into an application and get milestones, essay work, checklists, and requirement readiness.",
                    systemImage: "checklist",
                    tint: AppTheme.teal,
                    trailing: nil
                )
                TimelineRow(
                    title: "Learn from peers",
                    subtitle: "Verified admits and students surface artifacts and advice next to the programs you care about.",
                    systemImage: "person.3.fill",
                    tint: AppTheme.gold,
                    trailing: nil
                )
            }

            Button("Start guided setup") {
                withAnimation(.easeInOut) {
                    viewModel.hasStarted = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)

            if appState.showsDemoControls {
                Button("Load sample demo") {
                    appState.loadSampleData()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var onboardingView: some View {
        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
            HeroCard(
                eyebrow: "Guided setup",
                title: viewModel.steps[viewModel.stepIndex],
                subtitle: "Keep the input tight. Your progress saves to the workspace so you can resume cleanly."
            ) {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Step \(viewModel.stepIndex + 1) of \(viewModel.steps.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 120)
                }
            }

            switch viewModel.stepIndex {
            case 0:
                basicsForm
            case 1:
                academicForm
            case 2:
                testsAndFundingForm
            default:
                destinationsForm
            }

            if viewModel.stepIndex == viewModel.steps.count - 1 {
                SurfaceCard {
                    SectionTitle("What this profile unlocks")
                    DetailRow(label: "Estimated program matches", value: "\(viewModel.estimatedProgramCount)")
                    DetailRow(label: "Relevant scholarship options", value: "\(viewModel.estimatedScholarshipCount)")
                    DetailRow(label: "Profile completeness", value: "\(viewModel.stagedProfile.completenessScore)%")
                }
            }

            if let validation = viewModel.stepValidationMessage {
                Text(validation)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.warning)
            }

            HStack {
                if viewModel.stepIndex > 0 {
                    Button("Back") {
                        appState.saveOnboardingDraft(viewModel.draftProfile)
                        viewModel.previousStep()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button(viewModel.stepIndex == viewModel.steps.count - 1 ? "Finish setup" : "Continue") {
                    if viewModel.stepIndex == viewModel.steps.count - 1 {
                        appState.completeOnboarding(with: viewModel.stagedProfile)
                    } else {
                        appState.saveOnboardingDraft(viewModel.draftProfile)
                        viewModel.nextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .disabled(!viewModel.canAdvance)
            }
        }
        .onDisappear {
            if !appState.hasCompletedOnboarding {
                appState.saveOnboardingDraft(viewModel.draftProfile)
            }
        }
    }

    private var basicsForm: some View {
        SurfaceCard {
            SectionTitle("Applicant profile")
            TextField("Full name", text: $viewModel.draftProfile.fullName)
                .textFieldStyle(.roundedBorder)
            Text("Bangladesh is used as the starting context by default. You can refine profile and family funding details later from Account.")
                .font(.footnote)
                .foregroundStyle(AppTheme.subtleText)
            Picker("Target intake", selection: $viewModel.draftProfile.targetIntake) {
                Text("Fall 2027").tag("Fall 2027")
                Text("January 2028").tag("January 2028")
            }
            Picker("Degree level", selection: $viewModel.draftProfile.degreeLevel) {
                ForEach(DegreeLevel.allCases) { degree in
                    Text(degree.rawValue).tag(degree)
                }
            }
            Picker("Subject area", selection: $viewModel.draftProfile.subjectArea) {
                ForEach(AppConstants.supportedSubjects, id: \.self) { subject in
                    Text(subject).tag(subject)
                }
            }
            TextField("Intended major cluster", text: Binding(
                get: { viewModel.draftProfile.intendedMajorCluster ?? "" },
                set: { viewModel.draftProfile.intendedMajorCluster = $0.isEmpty ? nil : $0 }
            ))
        }
    }

    private var academicForm: some View {
        SurfaceCard {
            SectionTitle("Academic history")
            Picker("Secondary curriculum", selection: $viewModel.draftProfile.secondaryCurriculum) {
                ForEach(SecondaryCurriculum.allCases) { curriculum in
                    Text(curriculum.rawValue).tag(curriculum)
                }
            }

            if viewModel.draftProfile.degreeLevel == .undergrad {
                HStack {
                    Text("Secondary result %")
                    Spacer()
                    TextField("92", value: Binding(get: {
                        viewModel.draftProfile.secondaryResultPercent ?? 0
                    }, set: {
                        viewModel.draftProfile.secondaryResultPercent = $0 == 0 ? nil : $0
                    }), format: .number.precision(.fractionLength(1)))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .appDecimalFieldStyle()
                }
            } else {
                TextField("Undergraduate institution", text: $viewModel.draftProfile.undergraduateInstitution)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("GPA")
                    Spacer()
                    TextField("3.6", value: $viewModel.draftProfile.gpaValue, format: .number.precision(.fractionLength(2)))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .appDecimalFieldStyle()
                }
                HStack {
                    Text("Scale")
                    Spacer()
                    TextField("4.0", value: $viewModel.draftProfile.gpaScale, format: .number.precision(.fractionLength(1)))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .appDecimalFieldStyle()
                }
            }
        }
    }

    private var testsAndFundingForm: some View {
        SurfaceCard {
            SectionTitle("Tests and funding")
            Picker("English test", selection: $viewModel.draftProfile.englishTestType) {
                ForEach(EnglishTestType.allCases) { test in
                    Text(test.rawValue).tag(test)
                }
            }
            HStack {
                Text("Score")
                Spacer()
                TextField("7.5", value: $viewModel.draftProfile.englishTestScore, format: .number.precision(.fractionLength(1)))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .appDecimalFieldStyle()
            }
            if viewModel.draftProfile.degreeLevel == .undergrad {
                HStack {
                    Text("SAT")
                    Spacer()
                    TextField("1450", value: Binding(get: {
                        viewModel.draftProfile.satScore ?? 0
                    }, set: {
                        viewModel.draftProfile.satScore = $0 == 0 ? nil : $0
                    }), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .appNumericFieldStyle()
                }
                TextField("Activities (comma separated)", text: Binding(
                    get: { viewModel.draftProfile.activities.joined(separator: ", ") },
                    set: {
                        viewModel.draftProfile.activities = $0
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter(\.isNotEmpty)
                    }
                ))
            } else {
                Stepper(
                    "Work experience: \(viewModel.draftProfile.workExperienceYears) year\(viewModel.draftProfile.workExperienceYears == 1 ? "" : "s")",
                    value: $viewModel.draftProfile.workExperienceYears,
                    in: 0...10
                )
            }
            HStack {
                Text("Annual budget (USD)")
                Spacer()
                TextField("34000", value: $viewModel.draftProfile.annualBudgetUSD, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .appNumericFieldStyle()
            }
            HStack {
                Text("Tuition budget (USD)")
                Spacer()
                TextField("24000", value: $viewModel.draftProfile.tuitionBudgetUSD, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .appNumericFieldStyle()
            }
            HStack {
                Text("Annual budget (BDT)")
                Spacer()
                TextField("4200000", value: $viewModel.draftProfile.annualBudgetBDT, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 140)
                    .appNumericFieldStyle()
            }
            Toggle("Scholarship support is important", isOn: $viewModel.draftProfile.scholarshipNeeded)
        }
    }

    private var destinationsForm: some View {
        SurfaceCard {
            SectionTitle("Destination fit")
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferred countries")
                    .font(.subheadline.weight(.semibold))
                ForEach(AppConstants.supportedCountries, id: \.self) { country in
                    Toggle(
                        country,
                        isOn: Binding(
                            get: { viewModel.draftProfile.preferredCountries.contains(country) },
                            set: { isSelected in
                                if isSelected {
                                    if !viewModel.draftProfile.preferredCountries.contains(country) {
                                        viewModel.draftProfile.preferredCountries.append(country)
                                    }
                                } else {
                                    viewModel.draftProfile.preferredCountries.removeAll { $0 == country }
                                }
                            }
                        )
                    )
                }
            }
        }
    }
}
