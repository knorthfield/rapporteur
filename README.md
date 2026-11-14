# Rapporteur

Quick entry for GitHub issues on iPhone. Open the app, type, send. The screen clears for the next issue.

- The keyboard is up at launch, with the title in focus.
- Label chips in the colours of the repository's labels.
- Favourite repositories: swipe left or right to change the repository.
- Offline outbox: an issue waits until GitHub accepts it.
- Sign-in with GitHub's device flow. The token stays in the Keychain. See [PRIVACY.md](PRIVACY.md).

## Build

Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```
scripts/build.sh   # generate the project and build for the simulator
scripts/run.sh     # build, install and launch on the simulator
scripts/test.sh    # run the tests
```

For a real device, set `DEVELOPMENT_TEAM` in `Local.xcconfig`.

## Licence

MIT. See [LICENSE](LICENSE).
