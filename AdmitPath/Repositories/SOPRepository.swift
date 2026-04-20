import Foundation

struct SOPRepository {
    func projects(in state: DemoState) -> [SOPProject] {
        state.sopProjects.sorted { $0.updatedAt > $1.updatedAt }
    }

    func project(id: String, in state: DemoState) -> SOPProject? {
        state.sopProjects.first { $0.id == id }
    }

    func project(for programID: String?, mode: SOPProjectMode? = nil, in state: DemoState) -> SOPProject? {
        state.sopProjects.first { project in
            project.programID == programID && (mode == nil || project.mode == mode)
        }
    }

    func save(project: SOPProject, in state: inout DemoState) {
        if let index = state.sopProjects.firstIndex(where: { $0.id == project.id }) {
            state.sopProjects[index] = project
        } else {
            state.sopProjects.append(project)
        }
    }
}
