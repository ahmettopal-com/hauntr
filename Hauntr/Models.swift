import Foundation
import Combine

final class Pane: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var command: String
    @Published var paneDescription: String
    @Published var execute: Bool
    @Published var splitDirection: SplitDirection?
    @Published var first: Pane?
    @Published var second: Pane?

    enum SplitDirection: String, Codable {
        case horizontal, vertical
    }

    var isLeaf: Bool { splitDirection == nil }

    init(command: String = "", paneDescription: String = "", execute: Bool = true) {
        self.id = UUID()
        self.command = command
        self.paneDescription = paneDescription
        self.execute = execute
        self.splitDirection = nil
        self.first = nil
        self.second = nil
    }

    private init(command: String, paneDescription: String, execute: Bool,
                 splitDirection: SplitDirection?, first: Pane?, second: Pane?) {
        self.id = UUID()
        self.command = command
        self.paneDescription = paneDescription
        self.execute = execute
        self.splitDirection = splitDirection
        self.first = first
        self.second = second
    }

    // MARK: - Split actions

    func splitHorizontally() {
        let left = Pane(command: command, paneDescription: paneDescription, execute: execute)
        let right = Pane()
        command = ""
        paneDescription = ""
        execute = true
        splitDirection = .horizontal
        first = left
        second = right
    }

    func splitVertically() {
        let top = Pane(command: command, paneDescription: paneDescription, execute: execute)
        let bottom = Pane()
        command = ""
        paneDescription = ""
        execute = true
        splitDirection = .vertical
        first = top
        second = bottom
    }

    /// Remove a child and collapse this container back into the remaining child
    func removeChild(_ child: Pane) {
        guard let remaining = (first?.id == child.id ? second : first) else { return }
        command = remaining.command
        paneDescription = remaining.paneDescription
        execute = remaining.execute
        splitDirection = remaining.splitDirection
        first = remaining.first
        second = remaining.second
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, command, paneDescription = "description", execute, splitDirection, first, second
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        command = try container.decode(String.self, forKey: .command)
        paneDescription = try container.decodeIfPresent(String.self, forKey: .paneDescription) ?? ""
        execute = try container.decode(Bool.self, forKey: .execute)
        splitDirection = try container.decodeIfPresent(SplitDirection.self, forKey: .splitDirection)
        first = try container.decodeIfPresent(Pane.self, forKey: .first)
        second = try container.decodeIfPresent(Pane.self, forKey: .second)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(command, forKey: .command)
        try container.encode(paneDescription, forKey: .paneDescription)
        try container.encode(execute, forKey: .execute)
        try container.encodeIfPresent(splitDirection, forKey: .splitDirection)
        try container.encodeIfPresent(first, forKey: .first)
        try container.encodeIfPresent(second, forKey: .second)
    }

    // MARK: - Deep copy

    func deepCopy() -> Pane {
        Pane(
            command: command,
            paneDescription: paneDescription,
            execute: execute,
            splitDirection: splitDirection,
            first: first?.deepCopy(),
            second: second?.deepCopy()
        )
    }

}

struct Project: Identifiable, Codable {
    var id = UUID()
    var name: String
    var displayName: String
    var path: String
    var rootPane: Pane
    var equalizeSplits: Bool
    var isHidden: Bool

    var label: String { displayName.isEmpty ? name : displayName }

    init(name: String = "", displayName: String = "", path: String = "",
         rootPane: Pane = Pane(), equalizeSplits: Bool = true, isHidden: Bool = false) {
        self.id = UUID()
        self.name = name
        self.displayName = displayName
        self.path = path
        self.rootPane = rootPane
        self.equalizeSplits = equalizeSplits
        self.isHidden = isHidden
    }

    enum CodingKeys: String, CodingKey {
        case id, name, displayName, path, rootPane, equalizeSplits, isHidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        path = try container.decode(String.self, forKey: .path)
        rootPane = try container.decode(Pane.self, forKey: .rootPane)
        equalizeSplits = try container.decode(Bool.self, forKey: .equalizeSplits)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }
}

// MARK: - ProjectItem (project or group header)

enum ProjectItem: Identifiable, Codable {
    case project(Project)
    case group(id: UUID, title: String, isHidden: Bool = false)

    var id: UUID {
        switch self {
        case .project(let p): return p.id
        case .group(let id, _, _): return id
        }
    }

    var asProject: Project? {
        if case .project(let p) = self { return p }
        return nil
    }

    var isHidden: Bool {
        switch self {
        case .project(let p): return p.isHidden
        case .group(_, _, let hidden): return hidden
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, project, id, title, isHidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "group":
            let id = try container.decode(UUID.self, forKey: .id)
            let title = try container.decode(String.self, forKey: .title)
            let isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
            self = .group(id: id, title: title, isHidden: isHidden)
        default:
            let project = try container.decode(Project.self, forKey: .project)
            self = .project(project)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .project(let p):
            try container.encode("project", forKey: .type)
            try container.encode(p, forKey: .project)
        case .group(let id, let title, let isHidden):
            try container.encode("group", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(isHidden, forKey: .isHidden)
        }
    }
}
