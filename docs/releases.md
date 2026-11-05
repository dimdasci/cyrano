# Releases

Status: accepted 2026-10-28.

How versions, the changelog and release notes work, how a release goes out and how the app will reach people. This is the only place where it's described; the README, the plan and the scripts link here.

## Version and build number

About shows "Version 0.1.1 (9)": the version and the build number.

- Version (`CFBundleShortVersionString`) — semver `major.minor.patch`, stored in one place: [App/Version.xcconfig](../App/Version.xcconfig). It isn't changed by hand; `scripts/release` sets it. During previews `minor` grows (0.2.0, 0.3.0), fixes within a preview bump `patch` (0.2.1); 1.0.0 is the first release we consider ready.
- Build number (`CFBundleVersion`) — the number of commits on `HEAD`. The build step [scripts/set-build-number](../scripts/set-build-number) writes it into the built app; it isn't changed by hand. The same version on different commits differs by build number, and the number leads back to the commit: `git rev-list --reverse HEAD | sed -n <number>p`.
  - CI fetches the full history (`fetch-depth: 0`), otherwise the number would be 1.
  - In a pull request CI builds the merge commit of the branch with `main`, so the number there is one more than for the branch's last commit.

## Changelog and release notes

They're written for the person who uses Cyrano. That person wants to know what changed in their hands, what got fixed and what doesn't work right yet.

- [CHANGELOG.md](../CHANGELOG.md) in the root is the single source. [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format, in English, like everything else in the project.
- A version's release notes are its section in `CHANGELOG.md` plus a fixed tail (requirements, installation, a link to all changes). `scripts/changelog notes <version>` assembles them; the same text is the body of the release PR and of the GitHub Release. Package 15 will take it for the Sparkle update window too.
- Who writes them: a PR with a change the user will notice adds the entries under `## [Unreleased]` itself. CI doesn't let a PR through without a change to `CHANGELOG.md`; a PR without visible changes (docs, CI, refactoring) gets the `skip-changelog` label.
- A version section: one or two sentences about the main thing, then the groups `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Known issues` — only the non-empty ones, in this order.

How to write entries:

- What the user sees or does, in their words and with the names from the interface: "Press the camera button in Context…" rather than "ContextBar gets a capture button".
- No file names, types, PRs, plan packages or internal terms. A fix describes which behavior was wrong; what changed in the code stays out.
- One thought per entry, verb in the present tense. Limitations and workarounds go to `Known issues`, honestly.
- Lines may be wrapped to the file width: line breaks are joined when the release notes are assembled.

A mistake in notes already published is fixed in `CHANGELOG.md` through a PR; then the `release` workflow is run by hand with that version, and it rewrites the GitHub Release.

## Releasing

One command on a clean `main` synced with `origin/main`; `## [Unreleased]` must have changes:

```bash
scripts/release 0.2.0
```

1. [scripts/release](../scripts/release) checks that the version is newer than the current one and that there is no tag or `release/0.2.0` branch yet.
2. In the `release/0.2.0` branch it moves `## [Unreleased]` to `## [0.2.0] - <today>` ([scripts/changelog](../scripts/changelog)), sets the version and runs `scripts/check`. If `[Unreleased]` is empty or the check fails, it returns to a clean `main`.
3. It commits the version and `CHANGELOG.md` and opens the PR "Release 0.2.0" into `main`; the PR body is the version's release notes.
4. A person reads the notes in the PR and merges it once CI has passed.
5. The [release.yml](../.github/workflows/release.yml) workflow sees the change to `App/Version.xcconfig` in `main`, puts the tag `v0.2.0` on that commit and publishes the GitHub Release "Cyrano 0.2.0" with the release notes. The build number is in the run summary.

Locally, all that's needed afterwards is `git pull`. Tags and GitHub Releases aren't created by hand.

## Rules

- `main` is protected: changes only through a PR, the `check` status is required, the branch must be up to date with `main`, force push and deletion are forbidden, admins included.
- Releases come only from `main`, a tag goes only on a commit in `main`. So release build numbers only grow, and a PR can be merged any way, squash included.
- Builds for users are made only by CI from a tag. Until that exists (see below), a release is a tag and a GitHub Release with notes, and the app is built locally.

## Distribution

Decided 2026-10-28; package 15 of the [plan](plan.md) does it before the app goes to people.

- A `.dmg` directly, without the Mac App Store. The App Store requires App Sandbox, and from inside it you can't read text in other apps through Accessibility or emulate ⌘C, and the whole capture rests on that.
- The path: Developer ID signing → Apple notarization → `.dmg` → GitHub Releases → automatic updates (Sparkle). All of these are steps of the workflow run on a tag.
- We buy the Apple Developer Program ($99 a year) when the package starts: without a Developer ID a build can't be notarized, macOS blocks it on first launch, and the Accessibility permission is lost with every version.
- Until then signing is local: a self-signed certificate from [scripts/make-signing-identity](../scripts/make-signing-identity), see the [README](../README.md). Without it Xcode signs ad-hoc, and macOS resets the Accessibility permission on every rebuild (02 T4).
