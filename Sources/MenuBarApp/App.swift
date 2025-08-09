import SwiftUI

@main
struct MenuBarApp: App {
    var body: some Scene {
        MenuBarExtra("Hello world", systemImage: "star.fill") {
            MenuBarExtraView()
        }
    }
}

struct MenuBarExtraView: View {
    var body: some View {
        VStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .frame(width: 200)
        .padding()
    }
}