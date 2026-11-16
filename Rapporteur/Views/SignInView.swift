import SwiftUI

/// Signs in with GitHub's device flow: the user types a short code on github.com.
struct SignInView: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var deviceCode: DeviceCode?
    @State private var problem: String?
    @State private var attempt = 0

    private let client = GitHubClient()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "smallcircle.filled.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Sign in to GitHub")
                .font(.title2.bold())

            if let deviceCode {
                Text("Type this code on GitHub:")
                    .foregroundStyle(.secondary)
                Text(deviceCode.userCode)
                    .font(.system(.largeTitle, design: .monospaced).bold())
                    .textSelection(.enabled)
                Button("Copy the code", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = deviceCode.userCode
                }
                .buttonStyle(.glass)
                Button("Open GitHub", systemImage: "safari") {
                    UIPasteboard.general.string = deviceCode.userCode
                    openURL(deviceCode.verificationUri)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            } else if let problem {
                Text(problem)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try again") { attempt += 1 }
                    .buttonStyle(.glassProminent)
            } else {
                ProgressView()
            }
        }
        .padding(32)
        .task(id: attempt) { await signIn() }
    }

    private func signIn() async {
        deviceCode = nil
        problem = nil
        do {
            let code = try await client.requestDeviceCode()
            deviceCode = code
            store.signIn(token: try await client.waitForToken(code))
        } catch is CancellationError {
        } catch GitHubError.signInFailed(let message) {
            deviceCode = nil
            problem = message
        } catch {
            deviceCode = nil
            problem = "No connection to GitHub."
        }
    }
}
