import SwiftUI

@main
struct CodeTalkerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 390, height: 590)
        #endif
    }
}
