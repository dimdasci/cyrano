# Code quality

Status: accepted 2026-10-27.

Goal: after each development iteration, one command confirms that the code is readable and maintainable and that the mess isn't growing. The idea comes from Bob Martin ([ub-mode](https://github.com/unclebob/ub-mode), [crapper](https://github.com/unclebob/crapper), [dryer](https://github.com/unclebob/dryer), [mutator](https://github.com/unclebob/mutator)): the agent writes code, deterministic tools check it against hard thresholds. His tools don't support Swift, so we use Swift counterparts.

## Running

```bash
scripts/check          # everything at once; prints all failures, exit 1 if there is at least one
scripts/check --fix    # reformat Swift files first, then check
```

Tools: `swift format` comes with Xcode, the rest are installed once:

```bash
brew install swiftlint periphery
npm install -g jscpd
```

The check covers code: `App/` and `Packages/`, including the eval runner `cyrano-eval`. `evals/` holds only case data and HTML window templates, and they aren't checked.

In CI the same `scripts/check` runs on every push to `main` and on every pull request: [.github/workflows/check.yml](../.github/workflows/check.yml). In a pull request it is preceded by a check that `CHANGELOG.md` has changed (or that the PR has the `skip-changelog` label), see [releases.md](releases.md#changelog-and-release-notes). The runner is `xcode-27` (a GitHub preview image with Xcode 27, needed for the macOS 27 SDK). SwiftLint and Periphery are installed from Homebrew at their latest versions, jscpd is pinned to the same version as locally.

## What is checked

| Step | Tool | Config | What it catches |
|---|---|---|---|
| Formatting | `swift format lint --strict` | [.swift-format](../.swift-format) | Style: 2 spaces, lines up to 100 characters, import order. Fixed by `--fix` |
| Compilation | `swift build` | [Package.swift](../Packages/CyranoCore/Package.swift) | Warnings are errors; strict concurrency (Swift 6); `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`; functions and expressions that take longer than 200 ms to type-check |
| Tests | `swift test` | — | CyranoCore behavior |
| Unused code | Periphery | [.periphery.yml](../Packages/CyranoCore/.periphery.yml) | Unused types, functions, properties, parameters. The public API of CyranoCore counts as used: it's the contract with App |
| Complexity and size | SwiftLint | [.swiftlint.yml](../.swiftlint.yml) | Thresholds below; plus `!`, `try!`, `as!`, IUO |
| Duplicates | jscpd | [.jscpd.json](../.jscpd.json) | Matching fragments of 6 lines and 60 tokens or more; any clone found is a failure |

## Thresholds

| Metric | Threshold | Comment |
|---|---|---|
| Cyclomatic complexity of a function | ≤ 10 | A `switch` over an enum doesn't count: no need to split it for the metric |
| Function body | ≤ 40 lines | |
| Closure body | ≤ 30 lines | A SwiftUI `body` this long is a reason to extract a subview |
| Type body | ≤ 250 lines | |
| File | ≤ 400 lines | excluding comment lines |
| Function parameters | ≤ 5 | more is a reason for a parameter type |
| Nesting | types ≤ 2, functions ≤ 3 | |
| Tuple | ≤ 3 elements | more becomes a `struct` |

All thresholds are errors. They change only by the project owner's decision, never to make the check pass.

A rule may be suppressed only at one spot and with a reason:

```swift
// swiftlint:disable:next force_unwrapping - caller guarantees a non-empty list
let head = items.first!
```

Block `swiftlint:disable` without a matching `enable` is forbidden by the `blanket_disable_command` rule.

## Tests

- A test calls the code the way the app calls it and checks what the user will see. Substitutes only at the boundaries: the network (`ScriptedTransport`), the engine (`FakeEngine`), UserDefaults with its own suite. A test that checks the implementation or repeats another test gets deleted (review of 2026-11-01).
- A test body type-checks locally in about 40 ms at most (measurements vary by ±5 ms): CI can be four times slower (on 2026-11-05 a test that took 52 ms locally took 217 ms there), and the threshold is 200 ms. Measure with a sequential build in a separate folder: `swift build --build-tests -j 1 --scratch-path <tmp> -v -Xswiftc -Xfrontend -Xswiftc -debug-time-function-bodies`. Every `#expect` costs several milliseconds, and the most expensive ones compare optionals and untyped literals (`x?.origin == .check`): compute the values before `#expect` with explicit types, keep a test to one behavior with a few `#expect`s, move shared setup into a helper function.
- The boundaries with the system — sign-in through the browser and loopback, Keychain, ScreenCaptureKit, Accessibility — aren't covered by Core tests; we check them in the app with the `verify-app` skill.

## The app (App/)

- SwiftLint, jscpd and `swift format` check `App/` together with the packages.
- In the Xcode project's build settings: `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `SWIFT_STRICT_CONCURRENCY = complete`, the same upcoming features as in `Package.swift`, default isolation `MainActor`.
- Signing: ad-hoc by default ([App/Signing.xcconfig](../App/Signing.xcconfig)), so the project builds everywhere, CI included. Locally `scripts/make-signing-identity` creates a self-signed certificate "Cyrano Local Signing" and `App/Signing.local.xcconfig` (not in git): the Accessibility permission is tied to the certificate and survives rebuilds.
- `scripts/check` builds the app with `xcodebuild` (into `.build/xcode`) and runs Periphery on the Xcode project.
- `retain_public` for CyranoCore stays for now: the app scan doesn't check the package's public API. Remove it once Periphery scans both together.

## Later

Postponed while there is little code:

- CRAP — complexity × lack of test coverage per function: `swift test --enable-code-coverage` + `llvm-cov export` + complexity. Or add Swift to crapper.
- Mutation testing — on the changed files before a commit (Muter or a Swift module for mutator).
- Splitting CyranoCore into SPM targets (Auth, OpenAI, Prompts, Diff, Settings): the compiler will then forbid cycles and extra dependencies.

A caution from Martin's experiment: mechanically following the complexity metric bloated the code by 20–65% and doubled the number of functions without changing behavior. The metric is a signal; split by meaning, and stop before chasing the minimum number.
