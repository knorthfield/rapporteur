# Rapporteur

Quick entry for GitHub issues on iPhone. Open the app, type, send. The screen clears for the next issue.

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
