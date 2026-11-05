# Cyrano

A native macOS app that checks and improves short messages in any app: hotkey → a panel with the corrected text, explanations and a dialog with the model → copy the result and paste it yourself. It works through your ChatGPT subscription (Plus or Pro) with the official Sign in with ChatGPT.

Status: preview. The main flow, images as context, reading context from a window screenshot, the "Never change" dictionary and choosing a model for each operation all work. What's done, the next package and deviations from the spec are in [docs/plan.md](docs/plan.md).

## Repository layout

```
docs/                  spec, wireframes, research (start with docs/README.md)
Packages/CyranoCore/  Swift Package: OpenAI client, prompts, diff, dictionary, settings (tested without UI)
App/                   Xcode project of the app: UI, AX, hotkeys, windows
evals/                 example set and runner for testing prompts on ChatGPT models
scripts/check          code quality check: format, build, tests, linter, duplicates, dead code
scripts/release        releasing a version, see docs/releases.md
```

## Requirements

- macOS 27+, Apple Silicon, Xcode 27+
- A ChatGPT Plus or Pro subscription

## Building

```bash
open App/Cyrano.xcodeproj    # Cyrano scheme, Run
```

Or from the terminal:

```bash
xcodebuild -project App/Cyrano.xcodeproj -scheme Cyrano -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/Cyrano.app
```

Once, before the first build, create a local signing certificate; otherwise the Accessibility permission is reset on every rebuild:

```bash
scripts/make-signing-identity
```

On first launch: Continue with ChatGPT → the Accessibility permission → Screen Recording, if you keep reading context from the window turned on → ⌥⌘G in any text field. Core tests:

```bash
cd Packages/CyranoCore && swift test
```

Code quality check before a commit (tools and thresholds are in [docs/quality.md](docs/quality.md)):

```bash
brew install swiftlint periphery && npm install -g jscpd
scripts/check
```

Eval of reading context from a screenshot, with the same code the app uses (cases and format are in [evals/context/README.md](evals/context/README.md)):

```bash
swift build --package-path Packages/CyranoCore --product cyrano-eval
Packages/CyranoCore/.build/debug/cyrano-eval context evals/context/cases.json
```

Eval of fixes: Fix, Explain and the dialog, with the same code the panel uses. The runner writes a report, the agent grades it and settles disputed cases with the user ([evals/fix/README.md](evals/fix/README.md)):

```bash
Packages/CyranoCore/.build/debug/cyrano-eval fix evals/fix/cases.json gpt-6.1-sol > evals/private/fix-runs/gpt-6.1-sol.md
```

## Releases

```bash
scripts/release 0.2.0    # on main: a PR with the version and release notes; after the merge CI tags and publishes the release
```

What changed in each version is in [CHANGELOG.md](CHANGELOG.md). Versions, the changelog, the release procedure and distribution are in [docs/releases.md](docs/releases.md).

## License

MIT © 2026 Dim Kharitonov. See [LICENSE](LICENSE).
