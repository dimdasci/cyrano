# Cyrano

A native macOS app for checking short texts with models available through a ChatGPT subscription. Before you start, read [docs/README.md](docs/README.md): it has the spec and the reading order.

- `Packages/CyranoCore/` — logic (OpenAI client, authorization, prompts, diff, dictionary, settings), tested with `swift test`.
- `App/` — only UI, AX, hotkeys, windows. Keep logic that can be covered by a test in CyranoCore.
- `evals/` — the example set and the runner for testing prompts.

Everything is in English: docs, code and code comments, and everything the user sees (interface, CHANGELOG and release notes, README). Write docs by the voice and formatting rules in [docs/style.md](docs/style.md). Indent with 2 spaces.

## Releases

Procedure and rules: [docs/releases.md](docs/releases.md). Only `scripts/release <version>` on `main` releases a version; CI creates the tag and the GitHub Release with release notes after the release PR is merged. Don't change `App/Version.xcconfig`, don't create tags and don't create releases by hand. Changes reach `main` only through a PR.

Every PR with a change the user will notice adds entries under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md), written for the user by the rules in docs/releases.md. A PR without such changes gets the `skip-changelog` label. Before a PR, check `docs/plan.md`, the README and the affected specs against the change.

## Code quality

Details and thresholds: [docs/quality.md](docs/quality.md).

An iteration isn't finished until `scripts/check` passes. Run it before saying the work is done, and say what it showed in your final message. Fix formatting with `scripts/check --fix`.

When the check fails:

- Complexity or size — split the function or type by meaning: extract a step, introduce a type for a group of parameters, extract a subview. Don't chop it up mechanically to hit a number.
- Duplicate — move the shared part to one place. Don't copy a function with edits.
- Unused code — delete it. Don't keep code "for the future".
- Compiler warning — fix the cause.

Not allowed:

- loosening thresholds and rules in `.swiftlint.yml`, `.jscpd.json`, `.periphery.yml`, `Package.swift` without the user's consent;
- suppressing a rule without a reason. Only a targeted suppression is acceptable: `// swiftlint:disable:next <rule> - <reason>`, and mention it in your report;
- silencing the compiler: `!`, `try!`, `as!`, `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` — only with a comment explaining why it's safe.

How to write code:

- Test the behavior first, then write the code. The test calls the code the way the user calls it and checks what the user will see.
- Parse external data (API responses, JSON, AX) once, at the boundary, into types; trust them inside.
- Make invalid states unrepresentable: an `enum` with associated values instead of a set of optional fields and flags.
- One decision lives in one place. Remove what's unneeded first, then add.
