import SwiftUI

struct ProgramDetailView: View {
    @EnvironmentObject private var appState: AppState

    let match: ProgramMatch

    var body: some View {
        AppCanvas {
            HeroCard(
                eyebrow: "Program detail",
                title: match.program.name,
                subtitle: "\(match.program.universityName) • \(match.country) • \(match.program.durationMonths) months"
            ) {
                FitBadge(band: match.fitBand)
            }

            SurfaceCard {
                SectionTitle("Decision summary")
                Text(match.program.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                HStack(spacing: 8) {
                    SummaryPill(title: "\(match.score)/100 score", systemImage: "chart.bar.fill", tint: AppTheme.primary)
                    SummaryPill(title: match.program.degreeLevel.rawValue, systemImage: "graduationcap.fill", tint: AppTheme.teal)
                    SummaryPill(title: match.program.dataFreshness, systemImage: "clock.arrow.circlepath", tint: AppTheme.gold)
                }
            }

            SurfaceCard {
                SectionTitle("Cost and affordability")
                DetailRow(label: "Tuition", value: formatCurrency(match.program.tuitionUSD))
                DetailRow(label: "Estimated living cost", value: formatCurrency(match.program.estimatedLivingCostUSD))
                DetailRow(label: "Total annual cost", value: formatCurrency(match.program.totalCostOfAttendanceUSD))
                DetailRow(label: "Net cost after scholarships", value: formatCurrency(match.netCostEstimateUSD))
                DetailRow(label: "Funding gap", value: match.estimatedFundingGapUSD == 0 ? "No immediate gap" : formatCurrency(match.estimatedFundingGapUSD))
                Text(match.affordabilitySummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtleText)
                if let scenario = match.affordabilityScenario {
                    Text(scenario.netCostSummary)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Open funding planning") {
                        appState.openFunding()
                    }
                    .buttonStyle(.bordered)
                }
            }

            SurfaceCard {
                SectionTitle("Why it fits")
                Text(match.explanation)
                    .font(.subheadline)
                ForEach(match.fitReasonLedger) { item in
                    DetailRow(label: item.label, value: "\(item.score) • \(item.detail)")
                }
                DetailRow(label: "Subject alignment", value: match.program.subjectArea)
                DetailRow(label: "Country preference", value: appState.country(for: match.program))
                DetailRow(label: "Scholarships surfaced", value: "\(match.scholarshipCount)")
                DetailRow(label: "Confidence", value: match.confidence.rawValue.capitalized)
                if !match.program.bangladeshFitNote.isEmpty {
                    DetailRow(label: "Bangladesh fit note", value: match.program.bangladeshFitNote)
                }
            }

            SurfaceCard {
                SectionTitle("Requirements")
                if let secondary = match.requirement?.minSecondaryPercent {
                    DetailRow(label: "Secondary result minimum", value: "\(formatDecimal(secondary, digits: 1))%")
                }
                DetailRow(label: "Minimum GPA", value: match.requirement.map { "\(formatDecimal($0.minGPAValue, digits: 1))/\(formatDecimal($0.minGPAScale, digits: 1))" } ?? "Not listed")
                DetailRow(label: "IELTS minimum", value: match.requirement?.ieltsMin.map { formatDecimal($0, digits: 1) } ?? "Not listed")
                DetailRow(label: "CV required", value: (match.requirement?.cvRequired ?? false) ? "Yes" : "No")
                DetailRow(label: "SOP required", value: (match.requirement?.sopRequired ?? false) ? "Yes" : "No")
                DetailRow(label: "LOR count", value: "\(match.requirement?.lorCount ?? 0)")
                DetailRow(label: "Financial proof", value: (match.requirement?.financialProofRequired ?? false) ? "Yes" : "No")
                DetailRow(label: "Portfolio", value: (match.requirement?.portfolioRequired ?? false) ? "Yes" : "No")
            }

            SurfaceCard {
                SectionTitle("Deadlines")
                ForEach(appState.deadlines(for: match.program.id)) { deadline in
                    TimelineRow(
                        title: deadline.intakeTerm,
                        subtitle: "Application deadline: \(formatDate(deadline.applicationDeadline))",
                        systemImage: "calendar.badge.clock",
                        tint: AppTheme.warning,
                        trailing: relativeDaysString(to: deadline.applicationDeadline)
                    )
                    if let scholarshipDeadline = deadline.scholarshipDeadline {
                        TimelineRow(
                            title: "Scholarship submission",
                            subtitle: formatDate(scholarshipDeadline),
                            systemImage: "graduationcap.fill",
                            tint: AppTheme.gold,
                            trailing: relativeDaysString(to: scholarshipDeadline)
                        )
                    }
                }
            }

            if appState.scholarships(for: match.program).isNotEmpty {
                SurfaceCard {
                    SectionTitle("Scholarship opportunities")
                    ForEach(appState.scholarships(for: match.program).prefix(3)) { scholarship in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(scholarship.scholarship.name)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(title: scholarship.level.rawValue, color: scholarship.level.tint)
                            }
                            Text(scholarship.reason)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                        }
                    }
                }
            }

            if appState.communityArtifacts(for: match.program).isNotEmpty || appState.communityPosts(for: match.program).isNotEmpty {
                SurfaceCard {
                    SectionTitle("Peer intelligence", subtitle: "Verified artifacts rank ahead of open discussion.")
                    ForEach(appState.communityArtifacts(for: match.program).prefix(2)) { artifact in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(artifact.title)
                                    .font(.headline)
                                Spacer()
                                StatusBadge(title: artifact.verificationStatus.rawValue, color: artifact.verificationStatus.tint)
                            }
                            Text(artifact.summary)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                            ForEach(artifact.bulletHighlights, id: \.self) { highlight in
                                Text("• \(highlight)")
                                    .font(.footnote)
                            }
                        }
                    }
                    ForEach(appState.communityPosts(for: match.program).prefix(2)) { post in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.title)
                                .font(.headline)
                            Text(post.body)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.subtleText)
                                .lineLimit(4)
                        }
                    }
                    Button("Open community feed") {
                        appState.selectedTab = .community
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let url = URL(string: match.program.officialURL) {
                SurfaceCard {
                    SectionTitle("Primary source")
                    Link(destination: url) {
                        Label("Open official program page", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("Program")
        .appInlineNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(appState.savedPrograms.contains(where: { $0.id == match.program.id }) ? "Saved" : "Save") {
                    appState.toggleSavedProgram(match.program.id)
                }
                .buttonStyle(.bordered)

                Button(appState.comparedPrograms.contains(where: { $0.id == match.program.id }) ? "Compared" : "Compare") {
                    appState.toggleComparedProgram(match.program.id)
                }
                .buttonStyle(.bordered)

                Button(appState.application(for: match.program.id) == nil ? "Create application" : "Open application") {
                    if let existing = appState.application(for: match.program.id) {
                        appState.openApplication(existing.id)
                    } else if let application = appState.createApplication(from: match.program.id) {
                        appState.openApplication(application.id)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }
}
