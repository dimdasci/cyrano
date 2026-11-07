---
name: verify-app
description: Verify a change in the running Cyrano with the agent's own hands — relaunch a fresh build, open the panel on text from TextEdit, press buttons and menu items, read cards and Settings through Accessibility. Use before saying that a change in App is done, and when the user asks to check something in the app. Also covers what to do if macOS has revoked the Accessibility or Screen Recording permission.
---

# Verifying in the running Cyrano

The agent drives the app through Accessibility: the `.build/ax` utility (source [ax.swift](ax.swift)) reads the element tree, presses buttons, opens context menus and picks items; [capture.sh](capture.sh) opens the panel on text from TextEdit. Card text is read as text, without recognizing screenshots.

## Safety rules

The user may be working at the computer at the same time, and the keyboard and mouse are shared.

- Before you start, tell the user that for the next few minutes you'll be pressing keys and moving the mouse, and ask them not to switch windows.
- Keys (`ax key`, `osascript … keystroke`) go to the window with keyboard focus, which isn't always the frontmost app. The Cyrano panel takes keys without making Cyrano frontmost (System Events then names TextEdit), and the Keychain password prompt (`SecurityAgent`) takes them from everyone. So `capture.sh` first closes Cyrano's windows (`ax close`), waits for the password prompt to close, and only then checks that TextEdit is in front. For keys meant for a Cyrano window (Settings, onboarding), `lsappinfo info -only bundleid $(lsappinfo front)` must print `io.github.dimdasci.cyrano`. System Events can't tell: Cyrano is a menu bar agent (`LSUIElement`), and System Events calls it background only and never frontmost, while it names the last regular app instead. If something else is in front, don't press anything; say so.
- `ax appmenu "Settings…"` opens Settings but can't bring it to the front: macOS lets an app activate only on a real user action. A real click does it: `ax doubleclick` on a static text of the window, such as the title above the prompt editor (`Proofread, Main instructions…`). Then check the front app as above.
- The Keychain password prompt appears when a fresh build reads the token for the first time. Only the user closes it: tell them and wait, and send no keys meanwhile.
- Press Check only if the first line of `.build/ax windows` is `Proofreading — TextEdit`. Otherwise the panel may have taken text from the user's window: don't read it and don't send it for checking.
- The dictionary and settings are the user's real data. Before the check, save a copy of `~/Library/Application Support/Cyrano/dictionary.json` (or note that the file doesn't exist) and run `defaults export io.github.dimdasci.cyrano <file>`; afterwards compare, and if something changed, quit Cyrano and restore it. While Cyrano is running, it keeps the dictionary in memory and writes it back on the next change.
- Only the user changes system settings (permissions).
- If a step of the skill fails (`capture.sh`, `ax`), stop: find the cause (see "If keys didn't arrive") and fix the skill. Don't work around it with your own scripts, and don't continue the check around it.

## Setup

```bash
xcodebuild -project App/Cyrano.xcodeproj -scheme Cyrano -configuration Debug -derivedDataPath .build/xcode -quiet build
swiftc -O .claude/skills/verify-app/ax.swift -o .build/ax
pkill -x Cyrano; sleep 1; open .build/xcode/Build/Products/Debug/Cyrano.app; sleep 3
.build/ax windows    # no error means Accessibility is granted
```

If `.build/ax` prints `Accessibility is not granted to this process` or `osascript` prints `not allowed assistive access`, see "Permissions" below. A fresh build of Cyrano itself usually comes without its Accessibility and Screen Recording permissions; `capture.sh` says so, and "Permissions" says how to restore both.

## `ax` commands

| Command | What it does |
|---|---|
| `ax windows` | titles of Cyrano's windows, frontmost first |
| `ax close [window]` | closes Cyrano's windows; window is a substring of the title |
| `ax tree [window]` | the tree: `role \| label \| value \| hint`; window is a substring of the title (`Dictionary`) |
| `ax focused` | the element with keyboard focus: `role \| label \| value`; with `ax key`, checks the Tab order (05 §7) |
| `ax wait <text> [sec]` | waits until the text appears in a label or value (30 s by default) |
| `ax press <label>` | presses a button or link (`Check`, `Send`, `Copy`, `Undo`, `▸ 1 fix`, `Add Term`) |
| `ax select <text>` | selects text in the card text |
| `ax menu <text>` | opens the selection menu (`AXShowMenu`) and prints its items; checked ones with `✓` |
| `ax rightclick <text>` | a real right click on the element with this text in its label or value; prints the items |
| `ax pick <item>` | picks an item of the open context menu |
| `ax dismiss` | closes the open context menu without picking anything |
| `ax appmenu <item>` | an item of the app menu or of the menu bar icon (`Settings…`, `Check Text…`) |
| `ax set <placeholder/label> <value>` | types a value into a field (`Search`, `Term`); `@N` is the Nth field from the top (a SwiftUI TextEditor has no label: Context is `@1`) |
| `ax rows` | table and list rows; a cell with a label and a value prints both |
| `ax selectrow <value>` | selects a table or list row by a cell's value or label; `Casual` also finds `Casual, Modified` |
| `ax doubleclick <value>` | double-clicks the element with this value |
| `ax key <key> [command] [option] [shift] [control]` | presses a letter, `return`, `tab`, `space`, `up` or `down` like a keyboard does (through HID); only when the right app is in front |
| `ax announcements [sec]` | prints what Cyrano asks VoiceOver to announce during the next seconds (30 by default); start it in the background before the action, VoiceOver itself can stay off |

Save the output of `ax tree` to a file and search in it: with `ax tree | head` the utility may die from SIGPIPE and print nothing. If the command before it failed, the file is stale: don't read it, deal with the error first.

## Scenario

1. Open the panel: `.claude/skills/verify-app/capture.sh "I pushed the fix to Github, can you review it when you have a minute?"`. Wait 10–12 s: Cyrano reads the context from the screenshot, and Check stays disabled until then.
2. `.build/ax press Check`, `.build/ax wait "Version 1" 60`, then `.build/ax tree > …`. The card text is in the `AXTextArea` line: removed and added text come one after the other (`Github, can GitHub. Can`). Explanations arrive 5–15 s later: the summary changes from `Explaining…` to `1 fix`.
3. Check what the user sees: labels, the summary, the status line (`AXStaticText` at the bottom), the files the app writes.
   The dialog: `ax set "Ask or tell what to change" "<message>"`, `ax press Send`; an answer is an `AXStaticText` bubble, a new version a `Version N` card. To hear what VoiceOver would say, run `.build/ax announcements 40 > file &` before Send.
4. Close the panel and TextEdit: `.build/ax close`, `osascript -e 'tell application "TextEdit" to close every document saving no'`.

Examples that `gpt-6.1-sol` reliably fixes (handy for the dictionary): `Github → GitHub`, `kibana → Kibana`, `grafana → Grafana`. In a message context the model may leave slang alone (`tmrw`, `pls`), so don't rely on it.

Settings: `.build/ax appmenu "Settings…"`, the tab with `.build/ax press Dictionary`, then `ax tree Dictionary`, `ax rows`.

## Quirks

- SwiftUI button labels live in `AXAttributedDescription`; System Events (AppleScript, JXA) can't read them, which is why `ax` is written on `AXUIElement`.
- `AXShowMenu` works for the card text (`NSTextView`) and fails for SwiftUI `.contextMenu` (error -25204); use `ax rightclick` there. The right click lands in the center of the element; if the menu didn't open, check that the row has `.contentShape`, otherwise empty space doesn't catch the click.
- Close a menu opened by `ax menu` or `ax rightclick` right away, with `ax pick <item>` or `ax dismiss`, and only then press buttons. If `ax press` with the menu open removes the view the menu belongs to (Check removes "Text to check" and collapses Context), the menu never finishes tracking, KeyboardShortcuts keeps the hotkey paused, and ⌥⌘G doesn't work until Cyrano is relaunched. Signs: `capture.sh` prints `the panel did not open for TextEdit`, and according to the log the keys reached TextEdit. A user can't get into this state: their first click outside the menu closes it (2026-11-05).
- A button that disables itself when pressed (Restore Default) makes `ax press` print `AXPress failed: -25200` although the press worked. Check the result (`ax rows`, the file) instead of trusting the error.
- A button that opens a modal window (Import…, Export…) doesn't return from `AXPress` while the window is open: run `ax press` in the background (`… &`). A save window needs a path typed on the keyboard (⇧⌘G), only when Cyrano is in front; otherwise close it with `ax press Cancel`.

## VoiceOver

To hear what VoiceOver says, drive it through AppleScript. That needs "Allow VoiceOver to be controlled with AppleScript" in VoiceOver Utility → General; only the user turns it on. It's on when `/private/var/db/Accessibility/.VoiceOverAppleScriptEnabled` exists. Don't check with a `tell application "VoiceOver"` call: it starts VoiceOver.

1. Tell the user VoiceOver will speak aloud. Start it with `open /System/Library/CoreServices/VoiceOver.app`. On first start it shows a welcome window that blocks AppleScript; close it with Use VoiceOver (`osascript -e 'tell application "System Events" to tell process "VoiceOver Quickstart" to click button "Use VoiceOver" of window 1'`).
2. VoiceOver reads the window that has keyboard focus. Click into Cyrano's window first (`ax doubleclick` on a static text) and check with `lsappinfo info -only bundleid $(lsappinfo front)`.
3. Each step: `osascript -e 'tell application "VoiceOver"' -e 'tell vo cursor to move right' -e 'delay 1' -e 'return content of last phrase' -e 'end tell'`. Moves: `right`, `left`, `up`, `down`, `into item`, `out of item`, `to first item`. A group or a table is entered with `into item`; in a table `down` also selects the row.
4. Turn VoiceOver off: `osascript -e 'tell application "VoiceOver" to quit'`. Tell the user they can turn the AppleScript setting off.

## If keys didn't arrive

`capture.sh` prints `the panel did not open for TextEdit`, and the permissions are in place. Where the keys went is visible in the system log (local time):

```bash
/usr/bin/log show --last 2m --predicate '(process == "WindowServer" AND eventMessage CONTAINS "Keyboard event") OR (process == "tccd" AND eventMessage CONTAINS "AUTHREQ_RESULT")' --style compact
```

- `destinations for Keyboard event: (<keyboardFocus; TextEdit…>)` — the keys reached TextEdit, but ⌥⌘G didn't fire as a hotkey: WindowServer doesn't pass a hotkey that fired to a window, so there's no line for it. Check that Cyrano is alive and that the shortcut isn't being recorded in Settings. Press the hotkey with `ax key`: System Events presses (`osascript … keystroke`) reach the app but don't always trigger a global hotkey (on 2026-11-02 they triggered it neither for Cyrano nor for a separate probe with `RegisterEventHotKey`).
- `keyboardFocus; Cyrano…` or `SecurityAgent…` — the focus was held by the Cyrano panel or by the password prompt.
- `AUTHREQ_RESULT … authValue=2` — macOS allowed access; `authValue=0` — it denied it, see "Permissions".

## Permissions

The skill needs Accessibility (keys, clicks, reading the tree) and Screen Recording (screenshots for layout, `screencapture`). They're granted to the Claude Code process that runs the shell, which `osascript` and `ax` inherit:

```
Claude.app → disclaimer → ~/Library/Application Support/Claude/claude-code/<version>/<hash>/claude.app → zsh
```

To find the exact path, walk up from `$$` with `ps -o ppid=,comm= -p <pid>`.

Signs that a permission is missing: `ax` prints `Accessibility is not granted to this process`; `osascript` prints `not allowed assistive access (-1719)`; `screencapture -x file.png` prints `could not create image from display`. After a Claude Code update the path changes, and macOS may ask for the permissions again.

How to restore them:

1. Tell the user which permission is missing and what it's for. Don't turn anything on in System Settings yourself.
2. Trigger the system prompt: `swift .claude/skills/verify-app/permissions.swift`. Open the right pane: `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"` (or `?Privacy_ScreenCapture`).
3. Ask the user to turn on the "claude" row (the Claude Code icon; Claude.app is a different entry). If it isn't there: +, ⇧⌘G, the path to `claude.app` from the step above.
4. Accessibility takes effect immediately. Screen Recording only after Claude Code restarts (better answer Later to "Quit & Reopen" and restart afterwards, otherwise the session is interrupted); until then check through `ax`, without screenshots.
5. Verify: `swift .claude/skills/verify-app/permissions.swift` prints `true` for the needed permission.

Cyrano needs its own two permissions: Accessibility to read the selection, Screen Recording to read context from the window. Every build has a new ad-hoc signature, and after a rebuild macOS drops both of them, never only one. So whenever one is lost, restore both.

- Without Accessibility the hotkey still opens the panel, but as "Proofreading — Manual", with an "Accessibility not granted" icon and no text. `capture.sh` stops with "No Accessibility"; Cyrano's log has `capture: … trusted=false`.
- Without Screen Recording Context stays empty with no status at all: reading is skipped. `capture.sh` stops with "No Screen Recording"; Cyrano's log has `capture: … screenRecording=false`, and Settings → General shows "Open System Settings…" next to Screen Recording.

Turning the old Cyrano row off and on doesn't help: the row belongs to another build, and a grant given before a rebuild is void, because macOS keeps the stale entry and the switch does nothing. So there is one rule: no rebuild between the reset and the end of the check. Finish every build you need first (`scripts/check` builds the app too), then reset; if you rebuild after the reset, the whole cycle starts again. What works (2026-11-06). Only the user does the reset in step 1 and steps 3 and 4. Tell them all four steps in one message; after step 1 wait for their word, after steps 3 and 4 don't: watch the state yourself and go on as soon as it's granted (below).

1. You quit Cyrano. The user runs `tccutil reset All io.github.dimdasci.cyrano`.
2. You relaunch Cyrano from your checkout: `pkill -x Cyrano; open .build/xcode/Build/Products/Debug/Cyrano.app`.
3. The user allows Accessibility in the system prompt.
4. The user opens Cyrano's Settings → General → Open System Settings… next to Screen Recording and turns on the Cyrano switch there (in Device Control and Data Access). Screen Recording takes effect after Cyrano restarts, so you relaunch it once more, by its full path: `pkill -x Cyrano; open "$PWD/.build/xcode/Build/Products/Debug/Cyrano.app"`. If the user pressed "Quit & Reopen", macOS may reopen another checkout's build with the same bundle ID (on 2026-11-06 it opened the main checkout's build from a worktree), and that build has no permissions. Check with `ps -o command= -p $(pgrep -x Cyrano)` that the running Cyrano is yours.

To watch the state, open Settings (`.build/ax appmenu "Settings…"`; the window is titled by its tab, `General`) and read `.build/ax tree General` every few seconds: each permission's row shows `Granted` instead of the `Open System Settings…` button once Cyrano has it. Screen Recording may show `Granted` only after the relaunch. Then `capture.sh` confirms both.

The permissions are broad: with Accessibility the session's commands control any app, with Screen Recording they see the whole screen. The user can turn them off after the check.

## Report

Say what was checked in the app and how (`ax`, a screenshot), what couldn't be checked and why, and whether the dictionary and settings were restored.
