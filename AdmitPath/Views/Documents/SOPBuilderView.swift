import SwiftUI

struct SOPBuilderView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SOPBuilderViewModel

    init(initialProgramID: String? = nil, existingProject: SOPProject? = nil) {
        _viewModel = StateObject(
            wrappedValue: SOPBuilderViewModel(
                project: existingProject,
                selectedProgramID: initialProgramID,
                service: SOPGenerationService()
            )
        )
    }

    var body: some View {
        Group {
            if let profile = appState.profile {
                let scholarshipOptions = appState.scholarshipMatches.filter { $0.level != .unlikely }

                AppCanvas {
                    HeroCard(
                        eyebrow: "Essay workspace",
                        title: "Guide the story before generating the draft",
                        subtitle: "The value here is structure: guided prompts in, application-ready essay drafts and critique flags out."
                    ) {
                        VStack(alignment: .trailing, spacing: 10) {
                            SummaryPill(title: "\(viewModel.service.questions.count) prompts", systemImage: "text.badge.checkmark", tint: .white)
                            SummaryPill(title: viewModel.mode.rawValue, systemImage: "target", tint: .white)
                        }
                    }

                    SurfaceCard {
                        SectionTitle("Essay mode")
                        Picker("SOP mode", selection: $viewModel.mode) {
                            ForEach(SOPProjectMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Program context", selection: $viewModel.selectedProgramID) {
                            Text("General").tag(Optional<String>.none)
                            ForEach(appState.savedPrograms) { program in
                                Text("\(program.universityName) • \(program.name)")
                                    .tag(Optional(program.id))
                            }
                        }
                        .pickerStyle(.menu)

                        if viewModel.mode == .scholarship {
                            Picker("Scholarship context", selection: $viewModel.selectedScholarshipID) {
                                Text("None selected").tag(Optional<String>.none)
                                ForEach(scholarshipOptions, id: \.scholarship.id) { match in
                                    Text(match.scholarship.name).tag(Optional(match.scholarship.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    SurfaceCard {
                        SectionTitle("Questionnaire")
                        ForEach(Array(viewModel.service.questions.enumerated()), id: \.offset) { index, question in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Question \(index + 1)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.subtleText)
                                Text(question)
                                    .font(.subheadline.weight(.semibold))
                                TextEditor(text: Binding(
                                    get: { viewModel.answerTexts[index] },
                                    set: { viewModel.answerTexts[index] = $0 }
                                ))
                                .frame(minHeight: 120)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
                            }
                        }

                        Button("Generate outline and draft") {
                            let program = viewModel.selectedProgramID.flatMap { appState.environment.programRepository.program(id: $0) }
                            let scholarship = viewModel.selectedScholarshipID.flatMap { appState.environment.scholarshipRepository.scholarship(id: $0) }
                            Task {
                                await viewModel.generate(
                                    profile: profile,
                                    program: program,
                                    scholarship: scholarship,
                                    gateway: appState.environment.sopGateway
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                        .disabled(viewModel.isGenerating)

                        if viewModel.isGenerating {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Generating a draft and critique.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.subtleText)
                            }
                        }

                        if let generationError = viewModel.generationError {
                            Text(generationError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.warning)
                        }
                    }

                    if viewModel.generatedOutline.isNotEmpty {
                        SurfaceCard {
                            SectionTitle("Outline")
                            ForEach(viewModel.generatedOutline, id: \.self) { line in
                                Text("• \(line)")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if viewModel.generatedDraft.isNotEmpty {
                        SurfaceCard {
                            SectionTitle("Draft")
                            Text(viewModel.generatedDraft)
                                .font(.subheadline)

                            if viewModel.critiqueFlags.isNotEmpty {
                                SectionTitle("Critique flags", subtitle: "These are warnings, not hard failures.")
                                ForEach(viewModel.critiqueFlags) { flag in
                                    HStack(alignment: .top) {
                                        StatusBadge(title: flag.type.rawValue, color: AppTheme.warning)
                                        Text(flag.message)
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.subtleText)
                                    }
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(SOPRewriteAction.allCases) { action in
                                        Button(action.rawValue) {
                                            viewModel.rewrite(action)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }

                            Button("Save essay project") {
                                let title: String
                                if let program = viewModel.selectedProgramID.flatMap({ appState.environment.programRepository.program(id: $0) }) {
                                    title = "\(program.name) • \(viewModel.mode.rawValue)"
                                } else {
                                    title = viewModel.mode.rawValue
                                }

                                appState.saveSOPProject(
                                    title: title,
                                    programID: viewModel.selectedProgramID,
                                    scholarshipID: viewModel.selectedScholarshipID,
                                    mode: viewModel.mode,
                                    answers: viewModel.answers,
                                    generatedOutline: viewModel.generatedOutline,
                                    generatedDraft: viewModel.generatedDraft,
                                    critiqueFlags: viewModel.critiqueFlags
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.primary)
                        }
                    }

                    if viewModel.versions.isNotEmpty {
                        SurfaceCard {
                            SectionTitle("Version history")
                            ForEach(viewModel.versions.reversed()) { version in
                                DetailRow(label: "Version \(version.versionNumber)", value: formatDate(version.createdAt))
                            }
                        }
                    }
                }
                .navigationTitle("Essay Builder")
                .appInlineNavigationTitle()
            } else {
                ContentUnavailableView("Profile needed", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
    }
}
