# Changelog

What changed in Cyrano for the people who use it. Each version's section is also its release
notes on GitHub. How to write entries: [docs/releases.md](docs/releases.md#changelog-и-release-notes).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Removed

- Keyboard shortcuts inside the panel (⌘R, ⌘K, ⌘↩, ⇧⌘C) and ⌥⌘G next to Check Text… in the menu. Use the buttons instead; ⌥⌘G still opens the panel from any app and can be changed in Settings.

## [0.2.0] - 2026-10-28

Add what you're replying to as pictures: a screenshot of the conversation helps Cyrano match
your reply to it.

### Added

- Images as context. Press the camera button in Context to capture the window you're writing
  in, paste an image or a screenshot with ⌘V, or drop image files on the panel. Images are used
  on the next Check or Recheck.
- Thumbnails of the added images with a button to remove each one. After 10 images Cyrano warns
  that checks get slower and use more of your plan limit.
- Before asking for Screen Recording the first time, Cyrano explains why it needs it. Pasting
  and dropping images need no permission.

### Fixed

- A question or request in the dialog no longer appears twice while the answer is coming.
- Settings… now brings the Settings window to the front when it's hidden behind another app.
- Text in the Context field no longer touches the field's border.

### Known issues

- The tone setting (Friendly, Professional and others) has little effect on correct text. Ask
  for the tone in the dialog, for example "make it friendlier".

## [0.1.1] - 2026-10-28

Cyrano now waits for you to add context before checking.

### Changed

- The panel opens with the captured text and the Context field ready for what you're replying
  to. Press Check (⌘R) to start; after that the button becomes Recheck. Changing the type,
  tone or level before the first check no longer starts one.

## [0.1.0] - 2026-10-28

The first preview: check a short text in any app with your ChatGPT plan.

### Added

- Press ⌥⌘G (configurable) in any app to check the selected text or the whole field you're
  typing in. Cyrano reads it through Accessibility, by copying, or, as a last resort, from a
  screenshot of the window.
- A panel next to the field shows each version with the changes highlighted and a reason for
  each change. Undo any single change with one click.
- Context type, tone, level and output language in the panel header, remembered per app.
- A dialog under the versions: ask a question about the text or ask for a change in any
  language.
- Copy a version with one click or ⇧⌘C. Cyrano never types into your apps.
- Sign in with ChatGPT (Plus or Pro). Text goes only to OpenAI and isn't stored there.
- Menu bar menu: Check Text…, Check Clipboard, model choice, account, Settings.

[Unreleased]: https://github.com/dimdasci/cyrano/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/dimdasci/cyrano/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/dimdasci/cyrano/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/dimdasci/cyrano/releases/tag/v0.1.0
