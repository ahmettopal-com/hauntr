import Foundation
import AppKit

enum GhosttyScript {

    static func generate(for project: Project, newWindow: Bool) -> String {
        var lines: [String] = []
        var counter = 0
        let escapedPath = escapeForAppleScript(project.path)

        lines.append("tell application \"Ghostty\"")
        lines.append("    activate")
        lines.append("")
        lines.append("    set cfg to new surface configuration")
        lines.append("    set initial working directory of cfg to \"\(escapedPath)\"")
        lines.append("")

        counter += 1
        let rootVar = "pane\(counter)"

        if newWindow {
            lines.append("    set win to new window with configuration cfg")
            lines.append("    set \(rootVar) to terminal 1 of selected tab of win")
        } else {
            lines.append("    try")
            lines.append("        set win to front window")
            lines.append("        set \(rootVar) to terminal 1 of selected tab of win")
            lines.append("    on error")
            lines.append("        set win to new window with configuration cfg")
            lines.append("        set \(rootVar) to terminal 1 of selected tab of win")
            lines.append("    end try")
        }
        lines.append("")

        // Generate splits and collect leaf commands
        var splitLines: [String] = []
        var commands: [(varName: String, command: String, execute: Bool)] = []
        processPane(project.rootPane, varName: rootVar, counter: &counter,
                    splitLines: &splitLines, commands: &commands)

        // When reusing an existing window, cd into the project directory first
        if !newWindow {
            lines.append("    -- cd into project directory")
            lines.append("    input text \"cd '\(escapedPath)' && clear\" to \(rootVar)")
            lines.append("    send key \"enter\" to \(rootVar)")
            lines.append("")
        }

        // Emit split statements
        if !splitLines.isEmpty {
            lines.append("    -- Create pane layout")
            lines.append(contentsOf: splitLines)
            lines.append("")
        }

        // Emit commands for leaf panes
        if !commands.isEmpty {
            lines.append("    -- Run commands")
            for cmd in commands {
                let escaped = escapeForAppleScript(cmd.command)
                lines.append("    input text \"\(escaped)\" to \(cmd.varName)")
                if cmd.execute {
                    lines.append("    send key \"enter\" to \(cmd.varName)")
                }
            }
            lines.append("")
        }

        // Equalize splits
        if project.equalizeSplits && !splitLines.isEmpty {
            lines.append("    -- Equalize splits")
            lines.append("    perform action \"equalize_splits\" on \(rootVar)")
            lines.append("")
        }

        // Focus the first leaf pane
        let firstLeafVar = commands.first?.varName ?? rootVar
        lines.append("    focus \(firstLeafVar)")
        lines.append("")

        // Set tab title
        let tabTitle = escapeForAppleScript(project.displayName.isEmpty ? project.name : project.displayName)
        lines.append("    perform action \"set_tab_title:\(tabTitle)\" on \(rootVar)")
        lines.append("end tell")

        return lines.joined(separator: "\n")
    }

    /// Flatten nested containers that share the same split direction into a flat list.
    /// e.g. horizontal(horizontal(A, B), C) → [A, B, C]
    /// Children with a different direction are kept as-is.
    private static func collectSameDirectionChildren(
        _ pane: Pane, direction: Pane.SplitDirection
    ) -> [Pane] {
        guard pane.splitDirection == direction, let f = pane.first, let s = pane.second else {
            return [pane]
        }
        return collectSameDirectionChildren(f, direction: direction)
             + collectSameDirectionChildren(s, direction: direction)
    }

    private static func processPane(
        _ pane: Pane,
        varName: String,
        counter: inout Int,
        splitLines: inout [String],
        commands: inout [(varName: String, command: String, execute: Bool)]
    ) {
        guard let dir = pane.splitDirection else {
            // Leaf pane — collect command
            if !pane.command.isEmpty {
                commands.append((varName: varName, command: pane.command, execute: pane.execute))
            }
            return
        }

        // Flatten same-direction children into a sequential chain
        let children = collectSameDirectionChildren(pane, direction: dir)
        let directionStr = dir == .horizontal ? "right" : "down"

        // Generate sequential splits: each new pane splits from the previous one
        var vars = [varName]
        for i in 1..<children.count {
            counter += 1
            let newVar = "pane\(counter)"
            splitLines.append("    set \(newVar) to split \(vars[i - 1]) direction \(directionStr) with configuration cfg")
            vars.append(newVar)
        }

        // Recursively process each child (may contain splits in the other direction)
        for (child, v) in zip(children, vars) {
            processPane(child, varName: v, counter: &counter,
                        splitLines: &splitLines, commands: &commands)
        }
    }

    private static func escapeForAppleScript(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func run(for project: Project, newWindow: Bool) {
        let suffix = newWindow ? "window" : "here"
        let scriptPath = ("~/.config/hauntr/scripts/\(project.name)-\(suffix).applescript" as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: scriptPath) else {
            let alert = NSAlert()
            alert.messageText = "Script Not Found"
            alert.informativeText = "Script not found. Please save the project in Hauntr to regenerate it."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [scriptPath]
            let errorPipe = Pipe()
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? ""

                if proc.terminationStatus != 0 {
                    print("Hauntr: osascript failed (exit \(proc.terminationStatus)): \(errorString)")
                    DispatchQueue.main.async {
                        showErrorAlert(error: errorString, scriptPath: scriptPath)
                    }
                } else if !errorString.isEmpty {
                    print("Hauntr: osascript warnings: \(errorString)")
                }
            }

            try process.run()
        } catch {
            print("Hauntr: Failed to launch osascript: \(error)")
            showErrorAlert(error: error.localizedDescription, scriptPath: scriptPath)
        }
    }

    private static func showErrorAlert(error: String, scriptPath: String) {
        let alert = NSAlert()
        alert.messageText = "AppleScript Failed"
        alert.informativeText = error
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Copy Script")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            let script = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(script, forType: .string)
        }
    }
}
