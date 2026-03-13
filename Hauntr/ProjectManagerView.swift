import SwiftUI

struct ProjectManagerView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var editingGroupID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Manage Projects")
                .font(.headline)
                .padding()

            List {
                ForEach(store.items) { item in
                    switch item {
                    case .project(let project):
                        ProjectRow(project: project)
                    case .group(let id, let title, let isHidden):
                        GroupRow(
                            id: id,
                            title: title,
                            isHidden: isHidden,
                            editingGroupID: $editingGroupID
                        )
                    }
                }
                .onMove { source, destination in
                    store.moveItems(from: source, to: destination)
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.deleteItem(id: store.items[index].id)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            HStack {
                Button("Add Group") {
                    let newID = UUID()
                    store.addGroup(id: newID, title: "New Group")
                    editingGroupID = newID
                }
                Spacer()
                Button("Done") {
                    WindowManager.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Project row

private struct ProjectRow: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        HStack {
            Button(action: { store.toggleHidden(id: project.id) }) {
                Image(systemName: project.isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(project.isHidden ? .tertiary : .secondary)
            }
            .buttonStyle(.borderless)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.label)
                    .fontWeight(.medium)
                if !project.displayName.isEmpty {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(project.isHidden ? 0.4 : 1)
            Spacer()
            Text(project.path)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .opacity(project.isHidden ? 0.4 : 1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Group row

private struct GroupRow: View {
    let id: UUID
    let title: String
    let isHidden: Bool
    @Binding var editingGroupID: UUID?
    @EnvironmentObject var store: ProjectStore
    @State private var editedTitle: String = ""

    private var isEditing: Bool { editingGroupID == id }

    var body: some View {
        HStack {
            Button(action: { store.toggleHidden(id: id) }) {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(isHidden ? .tertiary : .secondary)
            }
            .buttonStyle(.borderless)
            if isEditing {
                TextField("Group title", text: $editedTitle)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline.bold())
                .onSubmit { commitEdit() }
                .onAppear {
                    editedTitle = title
                }
                .onExitCommand {
                    editingGroupID = nil
                }
            } else {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editedTitle = title
                        editingGroupID = id
                    }
                    .opacity(isHidden ? 0.4 : 1)
                Button(action: {
                    store.deleteItem(id: id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }

    private func commitEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.updateGroupTitle(id: id, title: trimmed)
        }
        editingGroupID = nil
    }
}
