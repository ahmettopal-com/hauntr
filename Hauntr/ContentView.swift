import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: ProjectStore
    var body: some View {
        if store.items.isEmpty {
            Text("No projects yet")
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.items.filter { !$0.isHidden }) { item in
                switch item {
                case .project(let project):
                    Menu(project.label) {
                        Button("Start here") {
                            GhosttyScript.run(for: project, newWindow: false)
                        }
                        Button("Start in new window") {
                            GhosttyScript.run(for: project, newWindow: true)
                        }
                        Divider()
                        Button("Edit") {
                            openEditWindow(for: project)
                        }
                        Button("Duplicate") {
                            let dup = store.duplicate(project)
                            openEditWindow(for: dup)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            store.delete(project)
                        }
                        Divider()
                        Text("\(project.name)")
                            .foregroundStyle(.secondary)
                    }
                case .group(_, let title, _):
                    Divider()
                    Text(title)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Divider()

        Button("Manage Projects...") {
            openManagerWindow()
        }

        Button("Add Project...") {
            openEditWindow()
        }

        Divider()

        Button("Install CLI...") {
            CLIInstaller.install()
        }

        Button("About Hauntr") {
            openAboutWindow()
        }

        Button("Check for Updates") {
            NSWorkspace.shared.open(URL(string: "https://github.com/ahmettopal-com/hauntr/releases/latest")!)
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openEditWindow(for project: Project? = nil) {
        let title = project == nil ? "Add Project" : "Edit Project"
        WindowManager.shared.open(title: title) {
            EditProjectView(existingProject: project)
                .environmentObject(store)
        }
    }

    private func openManagerWindow() {
        WindowManager.shared.open(title: "Manage Projects", minSize: NSSize(width: 400, height: 400)) {
            ProjectManagerView()
                .environmentObject(store)
        }
    }

    private func openAboutWindow() {
        WindowManager.shared.open(title: "About Hauntr", minSize: NSSize(width: 280, height: 260)) {
            AboutView()
        }
    }
}

// MARK: - About

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Hauntr")
                .font(.title.bold())

            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Link("by Ahmet Topal", destination: URL(string: "https://ahmettopal.com")!)
                    .font(.callout)
                Link("Follow me on \u{1D54F}", destination: URL(string: "https://x.com/ahmettopal")!)
                    .font(.callout)
            }
        }
        .padding(24)
        .frame(minWidth: 280, minHeight: 260)
    }
}
