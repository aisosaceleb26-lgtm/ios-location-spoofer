import SwiftUI

@main
struct OpenGPSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(nil) // Follow system light/dark
        }
    }
}
