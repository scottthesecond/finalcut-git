import SwiftUI

@main
struct PostSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let statusBarButton = statusBarItem?.button {
            statusBarButton.image = NSImage(systemSymbolName: "film", accessibilityDescription: "PostSync")
            statusBarButton.action = #selector(togglePopover)
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
    }
    
    @objc func togglePopover() {
        guard let popover = popover, let statusBarButton = statusBarItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .minY)
        }
    }
}
