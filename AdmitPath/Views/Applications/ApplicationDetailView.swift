import SwiftUI

struct ApplicationDetailView: View {
    @EnvironmentObject private var appState: AppState

    let applicationID: String
    @State private var notes = ""
    @State private var savedNotes = ""

    var body: some View {
        Group {
            if let application = appState.applicationRecord(id: applicationID) {
                let program = appState.environment.programRepository.program(id: application.programID)

                AppCanvas {
                    HeroCard(
                        eyebrow: "Application workspace",
                        title: application.programName,
                        subtitle: "\(application.universityName) • deadline \(formatDate(application.targetDeadline))"
                    ) {
                        StatusBadge(title: application.status.rawValue, color: application.status.tint)
                    }

                    SurfaceCard {
                        SectionTitle("Progress summary")
                        DetailRow(label: "Application system", value: appState.applicationSystem(for: application.country).rawValue)
                        DetailRow(label: "Completion", value: "\(application.completionPercent)%")
                        DetailRow(label: "Tasks open", value: "\(appState.tasks(for: application.id).filter { !$0.isCompleted }.count)")
                        DetailRow(label: "Tracked scholarships", value: "\(appState.trackedScholarships.count)")
                        ProgressView(value: Double(application.completionPercent), total: 100)
                            .tint(AppTheme.primary)
                    }

                    SurfaceCard {
                        SectionTitle("Planner timeline")
                        ForEach(appState.plannerItems(for: application.id)) { item in
                            TimelineRow(
                                title: item.title,
                                subtitle: item.type.rawValue,
                                systemImage: item.isCompleted ? "checkmark.circle.fill" : "calendar.badge.clock",
                                tint: item.isCompleted ? AppTheme.success : AppTheme.warning,
                                trailing: relativeDaysString(to: item.date)
                            )
                        }
                    }

                    SurfaceCard {
                        SectionTitle("Action checklist")
                        ForEach(appState.tasks(for: application.id)) { task in
                            Button {
                                appState.toggleTask(task.id, applicationID: application.id)
                            } label: {
                                TimelineRow(
                                    title: task.title,
                                    subtitle: task.taskType.rawValue,
                                    systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle.dashed",
                                    tint: task.isCompleted ? AppTheme.success : AppTheme.primary,
                                    trailing: relativeDaysString(to: task.dueDate)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SurfaceCard {
                        SectionTitle("Requirements and essays")
                        ForEach(appState.requirementItems(for: application.programID)) { item in
                            TimelineRow(
                                title: item.title,
                                subtitle: item.detail,
                                systemImage: item.isComplete ? "checkmark.circle.fill" : "circle.dashed",
                                tint: item.isComplete ? AppTheme.success : AppTheme.primary,
                                trailing: item.isComplete ? "Ready" : "Open"
                            )
                        }
                        Divider()
                        ForEach(appState.documentsChecklist()) { item in
                            TimelineRow(
                                title: item.type.rawValue,
                                subtitle: item.supportingNote,
                                systemImage: item.isReady ? "checkmark.circle.fill" : "circle.dashed",
                                tint: item.isReady ? AppTheme.success : AppTheme.primary,
                                trailing: item.isReady ? "Ready" : "Pending"
                            )
                        }
                        Button("Open essay workspace") {
                            appState.openDocuments(programID: application.programID)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                    }

                    if let program {
                        let scholarships = appState.scholarships(for: program)
                        if scholarships.isNotEmpty {
                            SurfaceCard {
                                SectionTitle("Funding links")
                                ForEach(scholarships.prefix(3)) { scholarship in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(scholarship.scholarship.name)
                                                .font(.headline)
                                            Text(scholarship.reason)
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.subtleText)
                                        }
                                        Spacer()
                                        Button(appState.trackedScholarships.contains(where: { $0.id == scholarship.scholarship.id }) ? "Tracked" : "Track") {
                                            appState.toggleTrackedScholarship(scholarship.scholarship.id)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }

                        let peerArtifacts = appState.communityArtifacts(for: program)
                        let peerPosts = appState.communityPosts(for: program)
                        if peerArtifacts.isNotEmpty || peerPosts.isNotEmpty {
                            SurfaceCard {
                                SectionTitle("Peer guidance")
                                ForEach(peerArtifacts.prefix(2)) { artifact in
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
                                    }
                                }
                                ForEach(peerPosts.prefix(2)) { post in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(post.title)
                                            .font(.headline)
                                        Text(post.body)
                                            .font(.footnote)
                                            .foregroundStyle(AppTheme.subtleText)
                                            .lineLimit(3)
                                    }
                                }
                                Button("Open community thread flow") {
                                    appState.selectedTab = .community
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    SurfaceCard {
                        SectionTitle("Notes", subtitle: "Keep a human judgment trail alongside the automated planning logic.")
                        TextEditor(text: $notes)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))

                        Button("Save notes") {
                            saveNotes(for: application.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                        .disabled(notes == savedNotes)
                    }
                }
                .navigationTitle("Application")
                .appInlineNavigationTitle()
                .onAppear {
                    loadNotes(for: application)
                }
                .onDisappear {
                    if notes != savedNotes {
                        saveNotes(for: application.id)
                    }
                }
            } else {
                ContentUnavailableView("Application not found", systemImage: "tray")
            }
        }
    }

    private func loadNotes(for application: ApplicationRecord) {
        notes = application.notes
        savedNotes = application.notes
    }

    private func saveNotes(for applicationID: String) {
        appState.updateApplicationNotes(notes, applicationID: applicationID)
        savedNotes = notes
    }
}
