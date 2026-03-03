# Contributing

## Building

```bash
cd MacroApp
xcodegen generate
xcodebuild -project KeyShare.xcodeproj -scheme KeyShare -configuration Debug build
```

## Testing

```bash
xcodebuild -project MacroApp/KeyShare.xcodeproj -scheme KeyShare -destination 'platform=macOS' test
pytest tests/
```

## Code Style

Run `swiftlint` before submitting. Follow existing patterns in the codebase.

## Pull Requests

Open PRs against `main`. Keep them focused.
