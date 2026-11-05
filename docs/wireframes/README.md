# Wireframes

The visual part of the UI spec. The text and rules are in [05-ui.md](../specs/05-ui.md); here is what it looks like and how to use it in development.

Wireframes record the original intent, and the specs are the reference: the wireframes still show Insert and keyboard shortcuts inside the panel, which the app no longer has (05 §2.9).

## Where things are

| What | Where | What for |
|---|---|---|
| Live canvas | [Cyrano UI wireframes](https://claude.ai/artifact/WC2VDYDdgmstvtfedoeizC) (private) | Look, click the interactive artboards, leave notes and comments |
| Artboard sources | `*.dc.html` in this folder | Versioned in git together with the spec; they show the exact sizes, texts and states |
| Canvas layout | `canvas.json` | Positions and names of the artboards |
| Screenshots | `png/` (empty for now) | Quick viewing without the canvas, links from specs and PRs |

Sync rule: edits are made on the canvas, then the sources are copied here, and [05-ui.md](../specs/05-ui.md) is updated in the same commit. If a wireframe and the spec disagree, that's a documentation bug, and we fix both.

## Artboards → spec → SwiftUI

| Artboard | Interactive | 05-ui section | Future SwiftUI views |
|---|---|---|---|
| `Main.dc.html` — proofreading panel | yes: Context, screenshots, expanding changes, Never Change, language, input field and Send, dark theme (Tweaks) | §2.1–2.7, §2.9 | `ProofreadingPanel`, `PanelHeader`, `ContextBar`, `ConversationView`, `VersionCard`, `ChangeList`, `MessageBubble`, `Composer`, `StatusLine` |
| `States.dc.html` — panel states | no | §2.8 | `ProofreadingPanel` states (checking, no changes, nothing to check, network error, plan limit, signed out, no Accessibility) |
| `Onboarding.dc.html` — first launch | yes: steps, sign-in, permission | §1 | `OnboardingWindow`, `SignInStep`, `AccessibilityStep`, `ShortcutStep` |
| `MenuBar.dc.html` — menu bar menu | no | §4 | `MenuBarExtra` content |
| `Settings.dc.html` — settings | yes: tabs, toggles, dictionary search, prompt editor | §5 | `SettingsView` + `GeneralPane`, `StylePane`, `DictionaryPane`, `PromptsPane`, `AccountPane` |
| `About.dc.html` — About window | no | Screen map | the standard About panel (`orderFrontStandardAboutPanel`) with credits |

## Moving to SwiftUI

A wireframe is a sketch; we take its structure and texts and leave pixel-exact copying aside. When implementing:

- Colors are system ones, instead of the hex values from the wireframe: panel background `windowBackgroundColor`, cards `controlBackgroundColor`, secondary text `secondaryLabelColor`, separators `separatorColor`, accent `accentColor`. Diff highlighting: `systemGreen` 20% (errors, solid underline), `systemBlue` 15% (style, dashed), removed text struck through in `secondaryLabelColor`.
- Controls are standard: `Picker` with the `.menu` style (pop-up buttons in the header), `Toggle` (switches in Settings), `Form` with the `.grouped` style (Settings), `Table` (dictionary), `TextEditor` (dialog field, Context, prompt editor), `KeyboardShortcuts.Recorder` (keyboard shortcuts).
- Sizes are regular system ones: controls 22 pt high, Settings rows 40–44 pt, panel width 520–560 pt, version text font 14 pt, everything else 13 pt system.
- Texts are copied from the wireframe as they are (they're already in title case / sentence case per the HIG, 05-ui §6).
- Behavior comes from 05-ui: the interactivity in the wireframe's JS only imitates it.

## Next

Once SwiftUI views appear, every screen and state gets a `#Preview` with the same data as in the wireframe (the example with Ravi, Version 1 / Version 2, "Is this polite?"). From then on the live UI reference is the previews in Xcode, and the wireframes stay as the original intent.
