import SwiftUI

struct DocumentsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let checklist = appState.documentsChecklist()
        let readyCount = checklist.filter(\.isReady).count

        AppCanvas {
            HeroCard(
                eyebrow: "Essay workspace",
                title: "Move from requirements to a convincing submission package",
                subtitle: "This workspace now sits inside Apply rather than as a separate tab."
            ) {
                VStack(alignment: .trailing, spacing: 10) {
                    SummaryPill(title: "\(readyCount)/\(checklist.count) ready", systemImage: "checkmark.seal.fill", tint: .white)
                    SummaryPill(title: "\(appState.homeSnapshot.sopProgress)% SOP", systemImage: "doc.text.fill", tint: .white)
                }
            }

            SurfaceCard {
                SectionTitle("Checklist")
                ForEach(checklist) { item in
                    TimelineRow(
                        title: item.type.rawValue,
                        subtitle: item.supportingNote,
                        systemImage: item.isReady ? "checkmark.circle.fill" : "circle.dashed",
                        tint: item.isReady ? AppTheme.success : AppTheme.primary,
                        trailing: item.isReady ? "Ready" : "Pending"
                    )
                }
            }

            SurfaceCard {
                SectionTitle("Essay Builder", subtitle: "Guided questions, critique flags, and version history.")
                Button("Open essay workspace") {
                    appState.openDocuments(programID: appState.demoState.sopProjects.first?.programID)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
            }

            if let project = appState.demoState.sopProjects.first, !project.generatedDraft.isEmpty {
                SurfaceCard {
                    SectionTitle("Recent essay draft", subtitle: project.title)
                    Text(project.generatedDraft)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.subtleText)
                        .lineLimit(10)
                }
            }
        }
        .navigationTitle("Essay Workspace")
    }
}
