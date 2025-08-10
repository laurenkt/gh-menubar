import SwiftUI
import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        // Return to accessory app mode when window closes
        NSApp.setActivationPolicy(.accessory)
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var hasAPIKey: Bool = false
    @Published var isSettingsPresented: Bool = false
    
    private let keychainManager = KeychainManager.shared
    private var settingsWindow: NSWindow?
    
    private init() {
        checkForExistingAPIKey()
    }
    
    func checkForExistingAPIKey() {
        hasAPIKey = keychainManager.getAPIKey() != nil
    }
    
    func saveAPIKey(_ apiKey: String) -> Bool {
        let success = keychainManager.saveAPIKey(apiKey)
        if success {
            hasAPIKey = true
        }
        return success
    }
    
    func getAPIKey() -> String? {
        return keychainManager.getAPIKey()
    }
    
    func deleteAPIKey() -> Bool {
        let success = keychainManager.deleteAPIKey()
        if success {
            hasAPIKey = false
        }
        return success
    }
    
    func openSettings() {
        // For LSUIElement apps, we need to temporarily change activation policy
        NSApp.setActivationPolicy(.regular)
        
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(contentViewController: hostingController)
            settingsWindow?.title = "Preferences"
            settingsWindow?.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("PreferencesWindow")
            
            // Set delegate to handle window closing
            settingsWindow?.delegate = WindowDelegate.shared
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeFirstResponder(settingsWindow?.contentView)
    }
}