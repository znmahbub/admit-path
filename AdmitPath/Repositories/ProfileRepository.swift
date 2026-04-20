import Foundation

struct ProfileRepository {
    func profile(in state: DemoState) -> StudentProfile? {
        state.profile
    }

    func save(profile: StudentProfile, in state: inout DemoState) {
        state.profile = profile
    }
}
