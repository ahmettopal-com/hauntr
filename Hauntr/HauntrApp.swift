import SwiftUI

@main
struct HauntrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProjectStore.shared

    var body: some Scene {
        MenuBarExtra("Hauntr", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "hauntr" else { continue }

            routeURL(url)
        }
    }

    private func routeURL(_ url: URL) {
        let store = ProjectStore.shared

        switch url.host {
        case "edit":
            let name = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !name.isEmpty else { return }
            guard let project = store.projects.first(where: { $0.name.lowercased() == name.lowercased() }) else {
                return
            }
            WindowManager.shared.open(title: "Edit Project") {
                EditProjectView(existingProject: project)
                    .environmentObject(store)
            }

        case "add":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let path = components?.queryItems?.first(where: { $0.name == "path" })?.value
            WindowManager.shared.open(title: "Add Project") {
                EditProjectView(prefillPath: path)
                    .environmentObject(store)
            }

        default:
            break
        }
    }
}
