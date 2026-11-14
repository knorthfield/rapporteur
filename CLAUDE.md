# Rapporteur

Quick entry for GitHub issues on iPhone (iOS 26+, portrait, one screen). The user types a title,
taps label chips, sends, and the screen clears for the next issue.

## Structure

- `Rapporteur/Model/GitHubClient.swift`: device-flow sign-in and the REST calls. The OAuth App
  client ID is a public constant. The OAuth App has "Expire user access tokens" off, so there is
  no refresh code.
- `Rapporteur/Model/Store.swift`: `@MainActor @Observable` state (account, favourites, labels,
  outbox), saved as JSON in Application Support. The token is in the Keychain (`Keychain.swift`).
- All sends go through the outbox (`Store.send` → `sendOutbox`). A network or server problem
  keeps the issue. A GitHub refusal marks it. A 401 signs the user out and keeps the outbox.
- `Rapporteur/Views/`: `ComposeView` (entry screen), `LabelChips`, `SignInView`, `SettingsView`,
  `RepositoryPickerView`.
- The model type `Label` has the same name as `SwiftUI.Label`. In views, write `SwiftUI.Label`
  for the SwiftUI type, or use `Button(_:systemImage:)`.

## Build and test

- `project.yml` is the source of truth. `Rapporteur.xcodeproj` is generated and git-ignored.
- `scripts/build.sh`, `scripts/run.sh`, `scripts/test.sh`. The scripts always exit 0: read the
  output (`** BUILD SUCCEEDED **`, `✘`, `** TEST FAILED **`). Do not chain a commit after them with `&&`.
- Tests use Swift Testing with `StubURLProtocol`. Suites that use the stub go in
  `extension NetworkStubbed` (serialized).
- Xcode 27.1 has no Simulator app. The simulator window is DeviceHub
  (`Xcode.app/Contents/Applications/DeviceHub.app`).
- If `xcodebuild` or `simctl` stays idle at 0% CPU, CoreSimulator is stuck: restart the Mac.
