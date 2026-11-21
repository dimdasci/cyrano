# Bug log

Bugs the user found in a released version, newest first. Each bug has what the user saw, what they expected and a hypothesis about the cause. A hypothesis is the current understanding: it's checked and confirmed before the fix.

## 0.12.0 (2026-11-08)

### 5. A change marked as an error turns into style

What the user saw: right after the diff showed, every change had a green fill and a green underline, the error mark. When the explanations arrived, some of them turned blue, style. A change shown as an error became a style suggestion.

Expected:
- Until the category is known, while Explain runs or after it failed, the changed block has a light graphite fill and a thick solid graphite underline. When the reason arrives, the mark turns into the solid green line of an error or the dashed blue line of style. A change with no reason keeps the graphite mark.
- The graphite line keeps at least 3:1 against the card and its own fill in both themes and with Increase Contrast, and the text on the fill keeps 4.5:1, struck-through words too.
- VoiceOver calls such a change a "change", then "error" or "style suggestion" once the reason arrives. The summary says "Explaining…" meanwhile. The list's `old → new` underline follows the same rule.

Hypothesis: `ChangeKind.init(_ reason:)` (Packages/CyranoCore/Sources/CyranoCore/Panel/PanelText.swift) turns a missing reason into `.error`: "Until its reason arrives, a change counts as an error". The card and the list mark every change by it, so before Explain answers, and for good when it fails (`.unavailable`), every change gets the error mark. The summary counts a change without a reason as a fix for the same reason.

### 4. A click on the Dock icon opens onboarding

What the user saw: with a proofreading panel open, a click on Cyrano's Dock icon opened the onboarding window, though sign-in and both permissions were done long ago.

Expected:
- Cyrano is an ordinary app: while it runs, it has a Dock icon, a place in ⌘Tab and its menus, with or without a window open. The menu bar icon is an extra the user can hide.
- A click on the Dock icon and launching the app again are the same event for the app, and both do the same thing. With a window of Cyrano open, they bring it forward, the proofreading panel first, and a minimized window comes back. With no window open, they open Settings.
- Launching Cyrano, by hand or at login, opens no window once the first setup is done; the Dock icon shows that it runs. Closing the last window leaves Cyrano running; ⌘Q quits it.
- Onboarding appears until the user presses Done once, and never after that; everything it offers is in Settings. After Sign Out, Settings → Account offers to sign in again. Onboarding says so: it welcomes the user, sets up what Cyrano needs, and tells them that later changes are in Settings.

Hypothesis: there are three causes.
- `applicationShouldHandleReopen` (App/Cyrano/CyranoApp.swift:58) always calls `showOnboarding()`. It dates from 0.1, when Cyrano had no Dock icon and the only way to reach it was to launch the app again with the menu bar icon hidden. Package 23 gave Cyrano a Dock icon while its windows are open, and a click on that icon goes to the same handler.
- Cyrano is an agent (`LSUIElement`, 02 T5): with no window open, the menu bar icon is the only sign that it runs. The system hides menu bar icons when the menu bar is crowded or the user turns them off, so a running Cyrano can be invisible. AppPresence switches the app to a regular one only while a window is open.
- With no window open, AppKit marks Cyrano for automatic termination: macOS counts it as quit and may end it, and ⌥⌘G with it, and a click on the Dock icon can reach no one.

### 3. A correct phrase is marked as an error, and the dialog says it's style

What the user saw: Version 2 changed `join` to `make it to` in "I can't join the party". The list marked it ● with a green highlight, which means an error, with the reason "'join the party' sounds unnatural here". Asked in the dialog whether it was style or grammar, the model answered that it's a style change. "I can't join the party" is correct English, so the card is wrong and the dialog is right.

Expected: a change that replaces correct, natural wording is style. The card and the dialog give the same category for the same change.

Hypothesis: package 21 added a line to the Explain prompt, "Wording a fluent speaker wouldn't use is an error, `wordChoice`, even when it is grammatical". It lets Explain call a correct, natural phrase unnatural and label its replacement an error. The eval shows the same pattern: in `meaning-02` the original `two times` is correct, and Terra and Luna label `two times` → `twice` as `wordChoice` in 2 of 3 runs (04 §5.3). Explain and the dialog judge the same change in separate calls, so the card and the dialog can disagree.

### 2. The list of changes and the text mark error and style differently

What the user saw: in the text, an error is highlighted green and a style change blue. In the list of changes, every marker is grey, and an error differs from a style change only by shape, ● and ◇. So the list uses a sign the text doesn't use, and lacks the one it does.

Expected: one mark tells an error from style everywhere, a thick underline. An error has a solid green line, a style change a dashed blue one, so the line type carries the category without color. In the text, the line and a fill a few steps lighter than it run under the whole changed block, the struck-through old words and the new words together, so a removed word is marked too. The fill only shows where the change is; the line tells the category, so the fill is light enough to keep the text on it readable. In the list, it's under the change itself, `тогда → Тогда`, and the bullet is an ordinary list bullet that carries no category. The lines stay readable in the light and dark themes and with Increase Contrast.

Hypothesis: the shapes have differed since the list appeared, while both places also used color. Package 23 measured the green and blue markers below 3:1 against the card and made them grey (`.foregroundStyle(.secondary)` in App/Cyrano/Panel/VersionCard.swift), and left the shapes as the only difference. The text highlight kept its color (`systemGreen` and `systemBlue` backgrounds in the same file).

### 1. ⌘↩ sends a stale message

What the user saw: typed a message in the dialog field and pressed ⌘↩. The bubble showed only "п", the first letter; the rest of the text was gone. The message had to be typed again and sent with the mouse.

Expected: ⌘↩ sends what is in the field at the moment it's pressed, the same as a click on Send, whether the text was typed, dictated or pasted.

Hypothesis: `PanelController.action` (App/Cyrano/Panel/PanelController.swift:44) copies `draft` into `message` when the action is built, and the closure sends that copy. The menu item Proofreading → Send (App/Cyrano/Panel/PanelAction.swift) is built from this action, and SwiftUI rebuilds menu commands only when something they read changes. That happened once, when the first letter made Send enabled, so the menu kept "п". ⌘↩ goes to the menu item before the button, so it sent "п" and cleared the field. The Send button builds its action on every render, so a click sent the full text.
