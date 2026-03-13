import SwiftUI
import Combine

final class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published var items: [ProjectItem] = []

    /// Convenience: all projects in order, excluding group headers
    var projects: [Project] {
        items.compactMap(\.asProject)
    }

    private let configDir: URL
    private let filePath: URL
    private let scriptsDir: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/hauntr")
        filePath = configDir.appendingPathComponent("projects.json")
        scriptsDir = configDir.appendingPathComponent("scripts")
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: filePath)
            // Try new [ProjectItem] format first
            items = try JSONDecoder().decode([ProjectItem].self, from: data)
        } catch {
            // Fall back to legacy [Project] format
            do {
                let data = try Data(contentsOf: filePath)
                let legacyProjects = try JSONDecoder().decode([Project].self, from: data)
                items = legacyProjects.map { .project($0) }
                // Re-save in new format
                saveJSON()
            } catch {
                print("Failed to load projects: \(error)")
                items = []
            }
        }
    }

    private func saveJSON() {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(items)
            try data.write(to: filePath, options: .atomic)
        } catch {
            print("Failed to save projects: \(error)")
        }
    }

    // MARK: - Project CRUD

    func add(_ project: Project) {
        items.append(.project(project))
        saveJSON()
        generateScript(for: project)
    }

    func update(_ project: Project) {
        guard let idx = items.firstIndex(where: { $0.id == project.id }) else { return }
        if let oldProject = items[idx].asProject, oldProject.name != project.name {
            removeScript(named: oldProject.name)
        }
        items[idx] = .project(project)
        saveJSON()
        generateScript(for: project)
    }

    func delete(_ project: Project) {
        removeScript(named: project.name)
        items.removeAll { $0.id == project.id }
        saveJSON()
    }

    func duplicate(_ project: Project) -> Project {
        let newName = nextAvailableName(base: project.name)
        let newDisplayName = project.displayName.isEmpty ? "" : "\(project.displayName) (Copy)"
        var dup = Project(
            name: newName,
            displayName: newDisplayName,
            path: project.path,
            rootPane: project.rootPane.deepCopy(),
            equalizeSplits: project.equalizeSplits
        )
        // Ensure a fresh ID
        dup.id = UUID()
        add(dup)
        return dup
    }

    private func nextAvailableName(base: String) -> String {
        // Strip trailing digits to get the root: "blog2" → "blog"
        let root = base.replacingOccurrences(of: "\\d+$", with: "", options: .regularExpression)
        let existingNames = Set(projects.map { $0.name.lowercased() })
        var candidate = "\(root)2"
        var counter = 2
        while existingNames.contains(candidate.lowercased()) {
            counter += 1
            candidate = "\(root)\(counter)"
        }
        return candidate
    }

    // MARK: - Group CRUD

    func addGroup(id: UUID = UUID(), title: String) {
        items.append(.group(id: id, title: title, isHidden: false))
        saveJSON()
    }

    func updateGroupTitle(id: UUID, title: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        if case .group(_, _, let isHidden) = items[idx] {
            items[idx] = .group(id: id, title: title, isHidden: isHidden)
        }
        saveJSON()
    }

    func toggleHidden(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        switch items[idx] {
        case .project(var p):
            p.isHidden.toggle()
            items[idx] = .project(p)
        case .group(let gid, let title, let isHidden):
            items[idx] = .group(id: gid, title: title, isHidden: !isHidden)
        }
        saveJSON()
    }

    func deleteItem(id: UUID) {
        if let item = items.first(where: { $0.id == id }), let project = item.asProject {
            removeScript(named: project.name)
        }
        items.removeAll { $0.id == id }
        saveJSON()
    }

    // MARK: - Reordering

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        saveJSON()
    }

    // MARK: - Script generation

    private func generateScript(for project: Project) {
        do {
            try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
            for (suffix, newWindow) in [("-here", false), ("-window", true)] {
                let script = GhosttyScript.generate(for: project, newWindow: newWindow)
                let scriptFile = scriptsDir.appendingPathComponent("\(project.name)\(suffix).applescript")
                try script.write(to: scriptFile, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to generate script for \(project.name): \(error)")
        }
    }

    private func removeScript(named name: String) {
        for suffix in ["-here", "-window"] {
            let scriptFile = scriptsDir.appendingPathComponent("\(name)\(suffix).applescript")
            try? FileManager.default.removeItem(at: scriptFile)
        }
        // Also remove legacy single script if it exists
        let legacy = scriptsDir.appendingPathComponent("\(name).applescript")
        try? FileManager.default.removeItem(at: legacy)
    }
}
