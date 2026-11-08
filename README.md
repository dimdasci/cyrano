# Cyrano

A native macOS app that checks and improves short messages in any app: hotkey → a panel with the corrected text, explanations and a dialog with the model → copy the result and paste it yourself. It works through your ChatGPT subscription (Plus or Pro) with the official Sign in with ChatGPT.

Status: preview. The main flow, images as context, reading context from a window screenshot, the "Never change" dictionary, choosing a model for each operation and editing the prompts in Settings → Prompts all work, with VoiceOver and with the keyboard alone. What's done, the next package and deviations from the spec are in [docs/plan.md](docs/plan.md).

## Choosing models

Settings → General has a model for each of three operations: reading context from the window, the check and the dialog, explanations. The defaults are what our evals favour ([docs/specs/04-prompts.md](docs/specs/04-prompts.md) §5, measured 2026-11-06):

| Operation | Default | Why | When to pick another |
|---|---|---|---|
| Read context | gpt-6.1-terra | Reads every eval window right, like Sol, and was the only model that never took more than 10 s in our runs, while you wait before Check | Sol reads as well but is slower; Luna sometimes returns only the name |
| Proofreading: the check and the dialog | gpt-6.1-sol | The steadiest on real messages and in the dialog: 67–68 of 70 cases and every dialog turn | Terra replies about a second faster in the dialog and slips more often on real messages; Luna is the fastest and the weakest on real messages |
| Explanations | gpt-6.1-sol | Labels errors and matters of taste right in 233 of 234 cases, and in our runs didn't call an optional point a rule | Luna gives the reasons about a second sooner and now and then calls an optional point a rule |

On the same work the three models spend the same number of tokens, so the choice changes speed and quality rather than tokens. We haven't measured how your ChatGPT plan counts each model toward its usage limit.

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
