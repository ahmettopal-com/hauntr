import SwiftUI

final class WindowManager {
    static let shared = WindowManager()
    private var window: NSWindow?

    func open<Content: View>(title: String, minSize: NSSize = NSSize(width: 700, height: 600), @ViewBuilder content: () -> Content) {
        // Close any existing edit window
        window?.close()

        let hostingView = NSHostingView(rootView: content())
        hostingView.setFrameSize(hostingView.fittingSize)
        let initialSize = NSSize(
            width: max(hostingView.fittingSize.width, minSize.width),
            height: max(hostingView.fittingSize.height, minSize.height)
        )

        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = title
        newWindow.minSize = minSize
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    func close() {
        window?.close()
        window = nil
    }
}
