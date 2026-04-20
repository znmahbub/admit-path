import Foundation

struct ApplicationRepository {
    func applications(in state: DemoState) -> [ApplicationRecord] {
        state.applications.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status < rhs.status
            }
            return lhs.targetDeadline < rhs.targetDeadline
        }
    }

    func application(for programID: String, in state: DemoState) -> ApplicationRecord? {
        state.applications.first { $0.programID == programID }
    }

    func tasks(for applicationID: String, in state: DemoState) -> [ApplicationTask] {
        state.tasks
            .filter { $0.applicationID == applicationID }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func plannerItems(for applicationID: String, in state: DemoState) -> [PlannerItem] {
        state.plannerItems
            .filter { $0.applicationID == applicationID }
            .sorted { $0.date < $1.date }
    }

    func createApplication(
        from program: Program,
        country: String,
        deadline: ProgramDeadline,
        tasks: [ApplicationTask],
        plannerItems: [PlannerItem],
        in state: inout DemoState
    ) -> ApplicationRecord {
        if let existing = application(for: program.id, in: state) {
            return existing
        }

        let application = ApplicationRecord(
            id: "app_\(program.id)",
            programID: program.id,
            universityName: program.universityName,
            programName: program.name,
            country: country,
            status: .shortlisted,
            completionPercent: 10,
            notes: "",
            linkedScholarshipIDs: [],
            createdAt: .now,
            targetDeadline: deadline.applicationDeadline
        )
        state.applications.append(application)
        state.tasks.append(contentsOf: tasks)
        state.plannerItems.append(contentsOf: plannerItems)
        return application
    }

    func update(applicationID: String, status: ApplicationStatus, in state: inout DemoState) {
        guard let index = state.applications.firstIndex(where: { $0.id == applicationID }) else { return }
        state.applications[index].status = status
    }

    func update(applicationID: String, notes: String, in state: inout DemoState) {
        guard let index = state.applications.firstIndex(where: { $0.id == applicationID }) else { return }
        state.applications[index].notes = notes
    }

    func update(applicationID: String, linkedScholarshipIDs: [String], in state: inout DemoState) {
        guard let index = state.applications.firstIndex(where: { $0.id == applicationID }) else { return }
        state.applications[index].linkedScholarshipIDs = linkedScholarshipIDs
    }

    func update(applicationID: String, completion: Int, in state: inout DemoState) {
        guard let index = state.applications.firstIndex(where: { $0.id == applicationID }) else { return }
        state.applications[index].completionPercent = completion
    }

    @discardableResult
    func toggleTask(taskID: String, in state: inout DemoState) -> ApplicationTask? {
        guard let index = state.tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        state.tasks[index].isCompleted.toggle()
        let updatedTask = state.tasks[index]

        for plannerIndex in state.plannerItems.indices where state.plannerItems[plannerIndex].id == taskID {
            state.plannerItems[plannerIndex].isCompleted = updatedTask.isCompleted
        }

        return updatedTask
    }

    func replacePlannerItems(applicationID: String, items: [PlannerItem], in state: inout DemoState) {
        state.plannerItems.removeAll { $0.applicationID == applicationID }
        state.plannerItems.append(contentsOf: items)
    }
}
