import SwiftUI

@main
struct RapporteurApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isSignedIn {
                    ComposeView()
                } else {
                    SignInView()
                }
            }
            .environment(store)
        }
    }
}
