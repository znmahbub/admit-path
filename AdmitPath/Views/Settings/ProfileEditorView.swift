import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var profile: StudentProfile
    @State private var targetUniversitiesText: String
    @State private var activitiesText: String
    @State private var honorsText: String

    init(initialProfile: StudentProfile) {
        _profile = State(initialValue: initialProfile)
        _targetUniversitiesText = State(initialValue: initialProfile.targetUniversityNames.joined(separator: ", "))
        _activitiesText = State(initialValue: initialProfile.activities.joined(separator: ", "))
        _honorsText = State(initialValue: initialProfile.honors.joined(separator: ", "))
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Full name", text: $profile.fullName)
                TextField("Nationality", text: $profile.nationality)
                TextField("Current country", text: $profile.currentCountry)
                TextField("Home city", text: $profile.homeCity)
                TextField("Target intake", text: $profile.targetIntake)
                Picker("Degree level", selection: $profile.degreeLevel) {
                    ForEach(DegreeLevel.allCases) { degree in
                        Text(degree.rawValue).tag(degree)
                    }
                }
                Picker("Subject area", selection: $profile.subjectArea) {
                    ForEach(AppConstants.supportedSubjects, id: \.self) { subject in
                        Text(subject).tag(subject)
                    }
                }
                TextField("Intended major cluster", text: Binding(
                    get: { profile.intendedMajorCluster ?? "" },
                    set: { profile.intendedMajorCluster = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Academic background") {
                Picker("Secondary curriculum", selection: $profile.secondaryCurriculum) {
                    ForEach(SecondaryCurriculum.allCases) { curriculum in
                        Text(curriculum.rawValue).tag(curriculum)
                    }
                }
                if profile.degreeLevel == .undergrad {
                    TextField("Secondary result %", value: Binding(get: {
                        profile.secondaryResultPercent ?? 0
                    }, set: {
                        profile.secondaryResultPercent = $0 == 0 ? nil : $0
                    }), format: .number.precision(.fractionLength(1)))
                    .appDecimalFieldStyle()
                } else {
                    TextField("Undergraduate institution", text: $profile.undergraduateInstitution)
                    TextField("GPA", value: $profile.gpaValue, format: .number.precision(.fractionLength(2)))
                        .appDecimalFieldStyle()
                    TextField("GPA scale", value: $profile.gpaScale, format: .number.precision(.fractionLength(1)))
                        .appDecimalFieldStyle()
                }
                Stepper("Work experience: \(profile.workExperienceYears)", value: $profile.workExperienceYears, in: 0...15)
                TextField("Activities (comma separated)", text: $activitiesText)
                TextField("Honors (comma separated)", text: $honorsText)
            }

            Section("Tests & budget") {
                Picker("English test", selection: $profile.englishTestType) {
                    ForEach(EnglishTestType.allCases) { test in
                        Text(test.rawValue).tag(test)
                    }
                }
                TextField("English score", value: $profile.englishTestScore, format: .number.precision(.fractionLength(1)))
                    .appDecimalFieldStyle()
                if profile.degreeLevel == .undergrad {
                    TextField("SAT score", value: Binding(get: {
                        profile.satScore ?? 0
                    }, set: {
                        profile.satScore = $0 == 0 ? nil : $0
                    }), format: .number)
                    .appNumericFieldStyle()
                } else {
                    TextField("GRE score", value: Binding(get: {
                        profile.greScore ?? 0
                    }, set: {
                        profile.greScore = $0 == 0 ? nil : $0
                    }), format: .number)
                    .appNumericFieldStyle()
                }
                TextField("Annual budget (USD)", value: $profile.annualBudgetUSD, format: .number)
                    .appNumericFieldStyle()
                TextField("Tuition budget (USD)", value: $profile.tuitionBudgetUSD, format: .number)
                    .appNumericFieldStyle()
                TextField("Annual budget (BDT)", value: $profile.annualBudgetBDT, format: .number)
                    .appNumericFieldStyle()
                TextField("Tuition budget (BDT)", value: $profile.tuitionBudgetBDT, format: .number)
                    .appNumericFieldStyle()
                Toggle("Scholarship needed", isOn: $profile.scholarshipNeeded)
                TextField("Standardized-test status", text: Binding(
                    get: { profile.standardizedTestStatus ?? "" },
                    set: { profile.standardizedTestStatus = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Countries") {
                ForEach(AppConstants.supportedCountries, id: \.self) { country in
                    Toggle(
                        country,
                        isOn: Binding(
                            get: { profile.preferredCountries.contains(country) },
                            set: { isSelected in
                                if isSelected {
                                    if !profile.preferredCountries.contains(country) {
                                        profile.preferredCountries.append(country)
                                    }
                                } else {
                                    profile.preferredCountries.removeAll { $0 == country }
                                }
                            }
                        )
                    )
                }
            }

            Section("Targets") {
                TextField("Target cities (comma separated)", text: Binding(
                    get: { profile.targetCities.joined(separator: ", ") },
                    set: { profile.targetCities = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter(\.isNotEmpty) }
                ))
                TextField("Target universities (comma separated)", text: $targetUniversitiesText)
            }

            Section("Counselor & family funding") {
                TextField("Counselor name", text: Binding(
                    get: { profile.counselorName ?? "" },
                    set: { profile.counselorName = $0.isEmpty ? nil : $0 }
                ))
                TextField("Counselor email", text: Binding(
                    get: { profile.counselorEmail ?? "" },
                    set: { profile.counselorEmail = $0.isEmpty ? nil : $0 }
                ))
                TextField("Guardian contribution (USD)", value: Binding(
                    get: { profile.familyFundingPlan?.guardianContributionUSD ?? 0 },
                    set: {
                        var plan = profile.familyFundingPlan ?? .empty
                        plan.guardianContributionUSD = $0
                        profile.familyFundingPlan = plan
                    }
                ), format: .number)
                .appNumericFieldStyle()
                TextField("Savings (USD)", value: Binding(
                    get: { profile.familyFundingPlan?.savingsUSD ?? 0 },
                    set: {
                        var plan = profile.familyFundingPlan ?? .empty
                        plan.savingsUSD = $0
                        profile.familyFundingPlan = plan
                    }
                ), format: .number)
                .appNumericFieldStyle()
                TextField("Monthly budget (USD)", value: Binding(
                    get: { profile.familyFundingPlan?.monthlyBudgetUSD ?? 0 },
                    set: {
                        var plan = profile.familyFundingPlan ?? .empty
                        plan.monthlyBudgetUSD = $0
                        profile.familyFundingPlan = plan
                    }
                ), format: .number)
                .appNumericFieldStyle()
                Toggle("Needs loan support", isOn: Binding(
                    get: { profile.familyFundingPlan?.needsLoanSupport ?? false },
                    set: {
                        var plan = profile.familyFundingPlan ?? .empty
                        plan.needsLoanSupport = $0
                        profile.familyFundingPlan = plan
                    }
                ))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView())
        .navigationTitle("Edit Profile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    profile.targetUniversityNames = targetUniversitiesText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter(\.isNotEmpty)
                    profile.activities = activitiesText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter(\.isNotEmpty)
                    profile.honors = honorsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter(\.isNotEmpty)
                    profile.onboardingComplete = true
                    appState.updateProfile(profile)
                    dismiss()
                }
            }
        }
    }
}
