import SwiftUI

struct MatchesListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filters = MatchFilters.empty

    var body: some View {
        let viewModel = ExploreViewModel(filters: filters)

        AppCanvas {
            HeroCard(
                eyebrow: "Discover",
                title: "Shortlist programs with transparent fit, requirements, and funding context",
                subtitle: "The ranking stays explainable: no fake admit probabilities, just clear reasoning across academics, destination fit, deadlines, and affordability."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(
                        title: "\(appState.matches.count) results",
                        systemImage: "list.bullet.rectangle",
                        tint: .white
                    )
                    SummaryPill(
                        title: "\(appState.comparedMatches.count) in compare",
                        systemImage: "rectangle.split.3x1",
                        tint: .white
                    )
                }
            }

            filtersView(viewModel: viewModel)

            if appState.comparedMatches.count >= 2 {
                NavigationLink {
                    ProgramCompareView(matches: appState.comparedMatches)
                } label: {
                    SurfaceCard {
                        SectionTitle("Compare shortlist")
                        Text("Compare cost, degree track, deadlines, scholarship availability, and fit band across your selected programs.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtleText)
                        HStack {
                            Text("Open comparison")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                ScholarshipListView()
            } label: {
                SurfaceCard {
                    SectionTitle("Scholarship signal")
                    Text("\(appState.scholarshipMatches.filter { $0.level != .unlikely }.count) scholarships currently look relevant to this profile. Funding context feeds directly into match explanations.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtleText)
                    HStack {
                        Text("Browse scholarships")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .buttonStyle(.plain)

            if appState.matches.isEmpty {
                EmptyStateCard(
                    title: "No matches yet",
                    message: "Complete onboarding or loosen the active filters to surface programs.",
                    buttonTitle: "Reset filters"
                ) {
                    filters = .empty
                }
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(Array(appState.matches.enumerated()), id: \.element.id) { index, match in
                        SurfaceCard {
                            Button {
                                appState.openProgram(match.program.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(match.program.name)
                                            .font(.headline)
                                        Spacer()
                                        FitBadge(band: match.fitBand)
                                    }
                                    Text("\(match.program.universityName) • \(match.country)")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text(match.explanation)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.subtleText)
                                    Text("Why it ranked: \(match.fitReasonLedger.prefix(2).map(\.label).joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    HStack(spacing: 8) {
                                        SummaryPill(title: match.program.degreeLevel.rawValue, systemImage: "graduationcap", tint: AppTheme.primary)
                                        SummaryPill(title: formatCurrency(match.program.totalCostOfAttendanceUSD), systemImage: "banknote.fill", tint: AppTheme.teal)
                                        SummaryPill(title: "Net \(formatCurrency(match.netCostEstimateUSD))", systemImage: "banknote", tint: AppTheme.gold)
                                        if let deadline = match.nextDeadline {
                                            SummaryPill(title: formatDate(deadline.applicationDeadline), systemImage: "calendar", tint: AppTheme.warning)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open shortlist result \(index + 1)")
                            .accessibilityIdentifier("discover-open-\(index)")

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Button(appState.savedPrograms.contains(where: { $0.id == match.program.id }) ? "Saved" : "Save") {
                                        appState.toggleSavedProgram(match.program.id)
                                    }
                                    .buttonStyle(.bordered)

                                    Button(appState.comparedPrograms.contains(where: { $0.id == match.program.id }) ? "Compared" : "Compare") {
                                        appState.toggleComparedProgram(match.program.id)
                                    }
                                    .buttonStyle(.bordered)

                                    Spacer()
                                }

                                Button(appState.application(for: match.program.id) == nil ? "Plan application" : "Open application") {
                                    if let existing = appState.application(for: match.program.id) {
                                        appState.openApplication(existing.id)
                                    } else if let application = appState.createApplication(from: match.program.id) {
                                        appState.openApplication(application.id)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button("View details") {
                                    appState.openProgram(match.program.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("discover-view-details-\(match.program.id)")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Discover")
        .onAppear {
            filters = appState.demoState.filters
        }
        .onChange(of: filters) { _, newValue in
            appState.updateFilters(newValue)
        }
    }

    @ViewBuilder
    private func filtersView(viewModel: ExploreViewModel) -> some View {
        SurfaceCard {
            SectionTitle("Filter rail", subtitle: "Keep the shortlist focused while the product deepens for the US, Canada, and the UK.")

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    filterMenu(
                        title: "Country",
                        value: filters.country ?? "All",
                        options: ["All"] + viewModel.availableCountries
                    ) { selected in
                        filters.country = selected == "All" ? nil : selected
                    }
                    filterMenu(
                        title: "Subject",
                        value: filters.subjectArea ?? "All",
                        options: ["All"] + viewModel.availableSubjects
                    ) { selected in
                        filters.subjectArea = selected == "All" ? nil : selected
                    }
                }

                HStack {
                    filterMenu(
                        title: "Degree",
                        value: filters.degreeLevel?.rawValue ?? "All",
                        options: ["All"] + viewModel.availableDegreeLevels.map(\.rawValue)
                    ) { selected in
                        filters.degreeLevel = viewModel.availableDegreeLevels.first(where: { $0.rawValue == selected })
                    }
                    filterMenu(
                        title: "Fit band",
                        value: filters.fitBand?.rawValue ?? "All",
                        options: ["All"] + FitBand.allCases.map(\.rawValue)
                    ) { selected in
                        filters.fitBand = FitBand.allCases.first(where: { $0.rawValue == selected })
                    }
                }

                HStack {
                    Text("Max annual cost")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    TextField(
                        "Optional",
                        value: Binding(
                            get: { filters.maxCostOfAttendance ?? 0 },
                            set: { filters.maxCostOfAttendance = $0 == 0 ? nil : $0 }
                        ),
                        format: .number
                    )
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
                    .appNumericFieldStyle()
                }

                Toggle("Scholarship-aware only", isOn: $filters.scholarshipOnly)
                    .toggleStyle(.switch)
            }

            Button("Reset filters") {
                filters = .empty
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func filterMenu(
        title: String,
        value: String,
        options: [String],
        apply: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    apply(option)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.subtleText)
                HStack {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppTheme.ink)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
