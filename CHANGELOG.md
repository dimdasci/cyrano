# Changelog

What changed in Cyrano for the people who use it. Each version's section is also its release
notes on GitHub. How to write entries: [docs/releases.md](docs/releases.md#changelog-и-release-notes).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Context read from the window now describes the conversation instead of copying messages from
  the screen: who you're writing to, the language, what it's about, whether you're replying,
  following up or starting a new topic, and how formal it is. It no longer comes out empty when
  only part of a long email is visible. Anything Cyrano can't tell from the window is left out
  for you to add.
- The output language follows the conversation: when Context shows that the conversation is in
  Spanish, the language pop-up switches to Spanish before you press Check, whatever language
  your draft is in. Pick another language to override it.
- The output language is no longer remembered for each app: you write in different languages
  in the same app. The Proofreading panel opens with Auto, and the language you pick applies to
  that panel only. Settings → Style → Per-app defaults no longer has a Language column.
- While Cyrano reads the conversation from the window, the Context title shows how long it has
  been reading and a Skip link to check without it. Reading now waits up to 20 seconds instead
  of 10, so a slow answer is no longer lost.
- When reading gives nothing, the Context title says why: no conversation in the window, it took
  too long, or an error. After a timeout or an error, Try Again reads the window again.

### Fixed

- A stopped request is no longer sent to OpenAI a second time.
- A closed Proofreading panel no longer stays in memory after a failed check.

## [0.5.0] - 2026-11-02

The Proofreading panel now fits its content, and Settings lets you choose the model for each
step of a check.

### Added

- Settings → General → Models: choose gpt-6.1-sol, gpt-6.1-terra or gpt-6-luna separately for
  reading context, for proofreading and the dialog, and for explanations. By default context
  is read with gpt-6-luna and everything else uses gpt-6.1-sol.
- Settings → General → Launch at login starts Cyrano when you log in to your Mac.
- Settings → Style → Per-app defaults shows the Context, Tone, Level and Language that Cyrano
  remembers for each app. Select an app and press − or Delete to reset it to Message · Neutral
  · Fluency · Auto.
- The first times you use the Proofreading panel, hints show where to add what you're replying
  to, what the camera button does and that you can ask for changes in the dialog field. A hint
  goes away for good once you close it or do what it says.
- Setup has a step for context from the window: turn Read context from the window on or off
  and grant Screen Recording right there. With it off, the camera button asks for Screen
  Recording the first time you press it.
- Cyrano has its own app icon.

### Changed

- The Proofreading panel is as tall as its content, up to 70% of the screen; after that only
  the versions and the dialog scroll. It grows downward and keeps its top edge in place. You
  can no longer resize it by dragging.
- The model is no longer chosen in the menu bar menu, and About no longer shows it.

### Fixed

- Settings and About no longer open behind the Proofreading panel. The panel stays in front of
  other apps, but not of Cyrano's own windows.
- Settings… and About Cyrano in the menu bar menu always open in front of the app you're in.
  Before, about one time in five the window opened behind it.
- Closing the Proofreading panel or the setup window frees its memory right away, including
  context screenshots. Before, the last closed panel stayed in memory until the next check.

### Known issues

- gpt-6.1-terra is offered but hasn't been tested on Cyrano's examples yet, so its corrections
  may differ in quality from gpt-6.1-sol.

## [0.4.0] - 2026-10-29

### Added

- Teach Cyrano words it should never change: names, product terms, slang. Select a word in a
  version card, right-click and choose Never Change. From the next check on, Cyrano keeps it
  exactly as you wrote it. The status line under the dialog field confirms it, with Undo.
- Right-click a change in the list under a version and choose Never Change for one of its
  words: the change is undone and the word is kept from then on, in one step.
- Settings → Dictionary lists your words with the date you added them. Search, add, edit with
  a double-click, delete, and import or export them as a text file with one word per line.
  Right-click a word in a card and choose Remove from Dictionary to let Cyrano correct it
  again.

## [0.3.0] - 2026-10-29

### Added

- Cyrano fills in Context for you. When you press ⌥⌘G in an app, it takes a screenshot of the
  window and reads who is in the conversation and the message you're replying to. It takes a
  few seconds; edit the result or add more before you press Check. Only the text goes with
  your check, not the screenshot. Turn it off in Settings → General → Read context from the
  window. Needs Screen Recording.
- You can type or paste the text to check right in the panel, and fix the captured text before
  the first check.
- Click an image thumbnail in Context, or select it and press Space, to see it full size with
  Quick Look. Handy for telling similar screenshots apart.

### Changed

- One button by the dialog field starts every check. It says Check before the first check and
  after you change the context with the dialog field empty; otherwise it says Send, and your
  message goes with the current context. The Check and Recheck buttons in Context are gone:
  Context is only for what you're replying to.
- Cyrano reads only the text you selected or the field you're typing in. It no longer selects
  everything with ⌘A or guesses your draft from a screenshot. When there's nothing to read, the
  panel opens with an empty field for your text.
- Check Text… opens the same panel instead of a separate window.
- The dialog field appears after the first check.
- The token counter shows one total.

### Fixed

- Pressing ⌥⌘G on the desktop no longer checks the names of the files on it.

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

[Unreleased]: https://github.com/dimdasci/cyrano/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/dimdasci/cyrano/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/dimdasci/cyrano/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/dimdasci/cyrano/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/dimdasci/cyrano/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/dimdasci/cyrano/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/dimdasci/cyrano/releases/tag/v0.1.0
