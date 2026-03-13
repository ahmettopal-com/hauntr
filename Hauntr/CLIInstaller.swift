import Foundation
import AppKit

enum CLIInstaller {
    static func install() {
        guard let scriptURL = Bundle.main.url(forResource: "hauntr", withExtension: "sh") else {
            showAlert(title: "Installation Failed", message: "CLI script not found in app bundle")
            return
        }

        let destination = "/usr/local/bin/hauntr"

        do {
            let escapedSource = scriptURL.path.replacingOccurrences(of: "'", with: "'\\''")
            let script = """
            do shell script "cp '\(escapedSource)' '\(destination)' && chmod +x '\(destination)'" with administrator privileges
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let pipe = Pipe()
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                showAlert(title: "CLI Installed", message: "hauntr was installed to \(destination)", style: .informational)
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                // User cancelled the admin dialog — exit code 1 with -128 error
                if errorString.contains("-128") { return }
                showAlert(title: "Installation Failed", message: errorString)
            }
        } catch {
            showAlert(title: "Installation Failed", message: error.localizedDescription)
        }
    }

    private static func showAlert(title: String, message: String, style: NSAlert.Style = .critical) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
