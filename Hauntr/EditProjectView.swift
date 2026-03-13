import SwiftUI
import Combine

// MARK: - Edit project form

struct EditProjectView: View {
    @EnvironmentObject var store: ProjectStore
    let existingProject: Project?
    @StateObject private var rootPane: Pane
    @State private var name: String
    @State private var displayName: String
    @State private var path: String
    @State private var equalizeSplits: Bool
    @State private var selectedPaneID: UUID?
    @State private var errorMessage: String?

    private var isEditing: Bool { existingProject != nil }

    private static let validNameRegex = /^[a-zA-Z0-9\-_]+$/

    private var nameFormatError: String? {
        if name.isEmpty { return nil }
        if name.wholeMatch(of: Self.validNameRegex) == nil {
            return "Name can only contain letters, numbers, hyphens and underscores"
        }
        return nil
    }

    private var duplicateNameError: String? {
        let isDuplicate = store.projects.contains {
            $0.name.lowercased() == name.lowercased() && $0.id != existingProject?.id
        }
        return isDuplicate ? "A project with this name already exists" : nil
    }

    private var validationError: String? {
        nameFormatError ?? duplicateNameError
    }

    init(existingProject: Project? = nil, prefillPath: String? = nil) {
        self.existingProject = existingProject
        if let p = existingProject {
            _rootPane = StateObject(wrappedValue: p.rootPane.deepCopy())
            _name = State(initialValue: p.name)
            _displayName = State(initialValue: p.displayName)
            _path = State(initialValue: p.path)
            _equalizeSplits = State(initialValue: p.equalizeSplits)
        } else {
            _rootPane = StateObject(wrappedValue: Pane())
            _name = State(initialValue: "")
            _displayName = State(initialValue: "")
            _path = State(initialValue: prefillPath ?? "")
            _equalizeSplits = State(initialValue: true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Edit Project" : "Add Project")
                .font(.headline)

            TextField("Project Name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Display Name (optional)", text: $displayName)
                .textFieldStyle(.roundedBorder)

            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                TextField("Project Path", text: $path)
                    .textFieldStyle(.roundedBorder)
                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        path = url.path
                    }
                }
            }

            Toggle("Equalize splits after launch", isOn: $equalizeSplits)
                .toggleStyle(.checkbox)

            Divider()

            Text("Pane Layout").font(.subheadline.bold())

            PaneLayoutView(pane: rootPane, selectedID: $selectedPaneID, onDelete: nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 200)
                .background(Color(nsColor: .separatorColor))
                .clipShape(RoundedRectangle(cornerRadius: 0))

            if let sid = selectedPaneID, let pane = rootPane.find(id: sid), pane.isLeaf {
                PaneEditorBar(pane: pane)
            } else {
                Text("Click a pane to edit its command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 24)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { WindowManager.shared.close() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add") {
                    guard validationError == nil else {
                        errorMessage = validationError
                        return
                    }
                    errorMessage = nil
                    var project = existingProject ?? Project()
                    project.name = name
                    project.displayName = displayName
                    project.path = path
                    project.rootPane = rootPane
                    project.equalizeSplits = equalizeSplits
                    if isEditing {
                        store.update(project)
                    } else {
                        store.add(project)
                    }
                    WindowManager.shared.close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || path.isEmpty || validationError != nil)
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Pane tree search

extension Pane {
    func find(id: UUID) -> Pane? {
        if self.id == id { return self }
        if let found = first?.find(id: id) { return found }
        if let found = second?.find(id: id) { return found }
        return nil
    }
}

// MARK: - Editor bar for selected pane

struct PaneEditorBar: View {
    @ObservedObject var pane: Pane

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("Command:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
                TextField("enter command", text: $pane.command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Toggle("Run", isOn: $pane.execute)
                    .toggleStyle(.checkbox)
                    .help("Press enter after typing command")
            }
            HStack(spacing: 10) {
                Text("Description:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
                TextField("optional label", text: $pane.paneDescription)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Recursive pane layout with GeometryReader

struct PaneLayoutView: View {
    @ObservedObject var pane: Pane
    @Binding var selectedID: UUID?
    var onDelete: (() -> Void)?

    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            layoutBody(in: geo.size)
        }
    }

    /// Flatten nested containers that share the same split direction into a flat list of children,
    /// paired with their immediate parent (for delete support).
    private static func collectSameDirectionChildren(
        _ pane: Pane, direction: Pane.SplitDirection
    ) -> [(child: Pane, parent: Pane)] {
        guard pane.splitDirection == direction, let f = pane.first, let s = pane.second else {
            return []
        }
        var result: [(child: Pane, parent: Pane)] = []
        if f.splitDirection == direction {
            result += collectSameDirectionChildren(f, direction: direction)
        } else {
            result.append((child: f, parent: pane))
        }
        if s.splitDirection == direction {
            result += collectSameDirectionChildren(s, direction: direction)
        } else {
            result.append((child: s, parent: pane))
        }
        return result
    }

    @ViewBuilder
    private func layoutBody(in size: CGSize) -> some View {
        let w = max(1, size.width)
        let h = max(1, size.height)

        if let dir = pane.splitDirection, pane.first != nil, pane.second != nil {
            let children = Self.collectSameDirectionChildren(pane, direction: dir)
            let count = CGFloat(children.count)
            let observed = pane

            switch dir {
            case .horizontal:
                let totalGap = gap * (count - 1)
                let cellW = max(1, floor((w - totalGap) / count))
                HStack(spacing: gap) {
                    ForEach(Array(children.enumerated()), id: \.element.child.id) { i, entry in
                        let isLast = i == children.count - 1
                        let thisW = isLast ? max(1, w - (cellW + gap) * (count - 1)) : cellW
                        PaneLayoutView(
                            pane: entry.child,
                            selectedID: $selectedID,
                            onDelete: {
                                entry.parent.removeChild(entry.child)
                                observed.objectWillChange.send()
                            }
                        )
                        .frame(width: thisW, height: h)
                    }
                }
            case .vertical:
                let totalGap = gap * (count - 1)
                let cellH = max(1, floor((h - totalGap) / count))
                VStack(spacing: gap) {
                    ForEach(Array(children.enumerated()), id: \.element.child.id) { i, entry in
                        let isLast = i == children.count - 1
                        let thisH = isLast ? max(1, h - (cellH + gap) * (count - 1)) : cellH
                        PaneLayoutView(
                            pane: entry.child,
                            selectedID: $selectedID,
                            onDelete: {
                                entry.parent.removeChild(entry.child)
                                observed.objectWillChange.send()
                            }
                        )
                        .frame(width: w, height: thisH)
                    }
                }
            }
        } else {
            PaneCellView(
                pane: pane,
                selectedID: $selectedID,
                onDelete: onDelete
            )
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Individual pane cell (only shown for leaf panes)

struct PaneCellView: View {
    @ObservedObject var pane: Pane
    @Binding var selectedID: UUID?
    var onDelete: (() -> Void)?
    @State private var isHovering = false

    private var isSelected: Bool { selectedID == pane.id }

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(nsColor: .textBackgroundColor))

            // Label: show description if set, otherwise command
            VStack(spacing: 2) {
                let label = pane.paneDescription.isEmpty ? pane.command : pane.paneDescription
                Text(label.isEmpty ? "—" : label)
                    .font(.system(.caption, design: pane.paneDescription.isEmpty ? .monospaced : .default))
                    .foregroundStyle(label.isEmpty ? .quaternary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if !pane.command.isEmpty {
                    Text(pane.execute ? "run" : "type")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(8)

            // Hover overlay with action buttons
            if isHovering {
                // Delete (top-right corner)
                if let onDelete {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                if selectedID == pane.id { selectedID = nil }
                                onDelete()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white, .red.opacity(0.85))
                            }
                            .buttonStyle(.borderless)
                            .padding(4)
                        }
                        Spacer()
                    }
                }

                // Split right (always available — cells are only shown for leaf panes)
                HStack {
                    Spacer()
                    Button(action: {
                        pane.splitHorizontally()
                        selectedID = pane.first?.id
                    }) {
                        Text("→")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 20, height: 28)
                            .background(.blue.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing, 2)
                }

                // Split down (always available — cells are only shown for leaf panes)
                VStack {
                    Spacer()
                    Button(action: {
                        pane.splitVertically()
                        selectedID = pane.first?.id
                    }) {
                        Text("↓")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .frame(width: 28, height: 20)
                            .background(.blue.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.borderless)
                    .padding(.bottom, 2)
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { selectedID = pane.id }
        .onHover { isHovering = $0 }
    }
}
