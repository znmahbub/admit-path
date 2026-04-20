import SwiftUI

@main
struct AdmitPathApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .background(AppTheme.background)
                .task {
                    await appState.start()
                }
                .onOpenURL { url in
                    Task {
                        await appState.handleOpenURL(url)
                    }
                }
        }
    }
}
