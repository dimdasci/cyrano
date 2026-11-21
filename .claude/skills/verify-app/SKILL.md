---
name: verify-app
description: Verify a change in the running Cyrano with the agent's own hands — relaunch a fresh build, open the panel on text from TextEdit, type letter by letter with real keys, press buttons, shortcuts and menu items, click the Dock icon, read cards and Settings through Accessibility. Use before saying that a change in App is done, and when the user asks to check something in the app. Also covers what to do if macOS has revoked the Accessibility or Screen Recording permission.
---

# Verifying in the running Cyrano

The agent uses the app the way a person does: it types with real keys, letter by letter, presses shortcuts after typing, clicks with the mouse, and reads what the app shows. The `.build/ax` utility (source [ax.swift](ax.swift)) types and presses keys through the HID tap, clicks, reads the element tree through Accessibility, presses buttons, opens context menus and picks items; [capture.sh](capture.sh) opens the panel on text from TextEdit. Card text is read as text, without recognizing screenshots.

Text never goes into a field by setting its Accessibility value: that skips the key events the app reacts to, and a check that does it passes while the app is broken. On 2026-11-08 ⌘↩ sent only the first letter of a typed message, and the check didn't see it because it had set the whole message at once. So: click into the field (`ax click`), type the text (`ax type`) in English and in Russian, then press the shortcut (`ax key return command`), and read what the app did with it.

## Safety rules

The user may be working at the computer at the same time, and the keyboard and mouse are shared.

- Before you start, tell the user that for the next few minutes you'll be pressing keys and moving the mouse, and ask them not to switch windows.
- Keys (`ax key`, `ax type`) go to the window with keyboard focus. The Keychain password prompt (`SecurityAgent`) takes them from everyone, so `capture.sh` first closes Cyrano's windows (`ax close`), waits for the password prompt to close, and only then checks that TextEdit is in front. The panel activates Cyrano when it opens, and a new panel opens in front. For keys meant for a Cyrano window (the panel, Settings, onboarding), `lsappinfo info -only bundleid $(lsappinfo front)` must print `io.github.dimdasci.cyrano`; `ax type` checks it itself and refuses otherwise. If something else is in front, don't press anything; say so.
- Clicks land where the element is on the screen. If the panel opened on a desktop (Space) other than the one on screen, the click hits whatever is there: before `ax click`, check that the window is on screen (`.build/ax windows` lists it, and the front app is Cyrano). If it isn't, stop and ask the user; they may be working on another desktop.
- `ax type` switches the keyboard layout to the one that has the next character (British, Russian) and puts back the user's layout at the end. Run it only while the user isn't typing.
- The Keychain password prompt appears when a fresh build reads the token for the first time. Only the user closes it: tell them and wait, and send no keys meanwhile.
- Press Check only if the first line of `.build/ax windows` is `Proofreading — TextEdit` (`Revisión — TextEdit`, `Проверка — TextEdit` in Spanish and Russian). Otherwise the panel may have taken text from the user's window: don't read it and don't send it for checking.
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

The interface speaks the Mac's language if it's Spanish or Russian. To check it in a given language, set it for the one process and never change the system language: `open .build/xcode/Build/Products/Debug/Cyrano.app --args -AppleLanguages '(es)'` (`(ru)`, `(en)`). Then the labels `ax` takes are in that language too: `ax press Revisar` (`Проверить`), `ax appmenu "Ajustes…"` (`Настройки…`), `ax wait "Versión 1"` (`Версия 1`). Their translations are in `App/Cyrano/Localizable.xcstrings`; `capture.sh` works in any of the three. A launch argument wins over Settings → General → Language for that process only and leaves the user's choice as it is. The pop-up itself writes the user's choice: after checking it, set it back to what it was (System, unless the defaults backup says otherwise).

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
| `ax click <placeholder/label>` | a real click into a field (`Ask or tell what to change`, `Search`, `Term`) or on a pop-up button, which opens its menu for `ax pick` (`Level`, then `ax pick Rewrite`); `@N` is the Nth one from the top |
| `ax type <text>` | types the text letter by letter with real keys, switching between the enabled layouts for each character (Latin and Cyrillic); `\n` is Return; only while Cyrano is in front |
| `ax dock [click\|press]` | says whether Cyrano's icon is in the Dock; `click` clicks it with the mouse, `press` presses it as VoiceOver does |
| `ax rows` | table and list rows; a cell with a label and a value prints both |
| `ax selectrow <value>` | selects a table or list row by a cell's value or label; `Casual` also finds `Casual, Modified` |
| `ax doubleclick <value>` | double-clicks the element with this value |
| `ax key <key> [command] [option] [shift] [control]` | presses a letter, `return`, `tab`, `space`, `escape`, `up` or `down` like a keyboard does (through HID); only when the right app is in front |
| `ax announcements [sec]` | prints what Cyrano asks VoiceOver to announce during the next seconds (30 by default); start it in the background before the action, VoiceOver itself can stay off |

Save the output of `ax tree` to a file and search in it: with `ax tree | head` the utility may die from SIGPIPE and print nothing. If the command before it failed, the file is stale: don't read it, deal with the error first.

## Scenario

1. Open the panel: `.claude/skills/verify-app/capture.sh "I pushed the fix to Github, can you review it when you have a minute?"`. Wait 10–12 s: Cyrano reads the context from the screenshot, and Check stays disabled until then.
2. `.build/ax press Check`, `.build/ax wait "Version 1" 60`, then `.build/ax tree > …`. The card text is in the `AXTextArea` line, as VoiceOver reads it: the version's text without the removed words (`… to GitHub. Can you …`). Explanations arrive 5–15 s later: the summary changes from `Explaining…` to `1 fix`.
3. Check what the user sees: labels, the summary, the status line (`AXStaticText` at the bottom), the files the app writes.
   The dialog: `ax click "Ask or tell what to change"`, `ax type "<message>"`, then `ax key return command` (⌘↩) or `ax press Send`; an answer is an `AXStaticText` bubble, a new version a `Version N` card. Check that the bubble holds the whole message, and that the field is empty after it went. Type one message in English and one in Russian (`ax type "сделай короче"`). To hear what VoiceOver would say, run `.build/ax announcements 40 > file &` before Send.
4. Close the panel and TextEdit: `.build/ax close`, `osascript -e 'tell application "TextEdit" to close (every document whose name is "cyrano-verify.txt") saving no'`. Close only that document: the user's own documents in TextEdit stay open and unsaved changes in them stay. Closing the panel while Cyrano is in front gives the keyboard back to TextEdit.

⌘↩ (`ax key return command`) presses Check or Send from anywhere in the panel; it is the key of Proofreading → Check or Send in the menu bar. Press it after typing, never on a field filled some other way.

With a panel open, ⌥⌘G in another app, Check Text… and Check Clipboard show a sheet on the panel: `Check New Text` (the default, `ax key return`) or `Return to Panel` (`ax key escape`); `ax press` works on both buttons.

Examples that `gpt-6.1-sol` reliably fixes (handy for the dictionary): `Github → GitHub`, `kibana → Kibana`, `grafana → Grafana`. In a message context the model may leave slang alone (`tmrw`, `pls`), so don't rely on it.

Settings: `.build/ax appmenu "Settings…"`, the tab with `.build/ax press Dictionary`, then `ax tree Dictionary`, `ax rows`. Typing into a Settings field: `ax click Search`, `ax type "kibana"`.

## Dock and launch

Cyrano is an ordinary app (02 T5, 05 §4): it's in the Dock while it runs, with or without a window. Check each of these as a person does it, and read the result:

- Launch with no window: `pkill -x Cyrano; open "$PWD/.build/xcode/Build/Products/Debug/Cyrano.app"; sleep 3`. Once onboarding is done and the sign-in and Accessibility are in place, `.build/ax windows` prints nothing, and `.build/ax dock` prints `Cyrano is in the Dock`.
- A Dock click with no window: `.build/ax dock click`, then `.build/ax windows` prints the Settings tab (`General`, or the tab used last) and the front app is Cyrano.
- A Dock click with the panel open: open the panel with `capture.sh`, click another app's window or open Settings, then `.build/ax dock click`; the first line of `.build/ax windows` is `Proofreading — TextEdit`. With the panel minimized (`ax key m command` while it's in front), the click brings it back.
- Launching again while it runs: `open "$PWD/.build/xcode/Build/Products/Debug/Cyrano.app"` does the same as the Dock click. Check with no window and with the panel open.
- Closing the last window: `ax key w command` while the window is in front, then `.build/ax windows` prints nothing, `pgrep -x Cyrano` still finds it and `.build/ax dock` still prints `Cyrano is in the Dock`.

The Dock doesn't always take a synthetic click: on 2026-11-21 `ax dock click` sometimes left no window and Finder in front while the pointer was on the icon, and the logs gave no cause, though the same press through Accessibility and the user's own click worked every time. When the click shows nothing, check the same state with `ax dock press`, and ask the user for one real click to confirm; don't count the synthetic click as the app's failure. The Dock click needs the Dock on screen; if the user has it hidden, `ax dock click` misses it: say so instead of working around it. Onboarding shows at launch until Done is pressed once (the `onboardingDone` key in the app's defaults); don't change that key in the user's defaults to test it.

## Quirks

- SwiftUI button labels live in `AXAttributedDescription`; System Events (AppleScript, JXA) can't read them, which is why `ax` is written on `AXUIElement`.
- `AXShowMenu` works for the card text (`NSTextView`) and fails for SwiftUI `.contextMenu` (error -25204); use `ax rightclick` there. The right click lands in the center of the element; if the menu didn't open, check that the row has `.contentShape`, otherwise empty space doesn't catch the click.
- Close a menu opened by `ax menu` or `ax rightclick` right away, with `ax pick <item>` or `ax dismiss`, and only then press buttons. If `ax press` with the menu open removes the view the menu belongs to (Check removes "Text to check" and collapses Context), the menu never finishes tracking, KeyboardShortcuts keeps the hotkey paused, and ⌥⌘G doesn't work until Cyrano is relaunched. Signs: `capture.sh` prints `the panel did not open for TextEdit`, and according to the log the keys reached TextEdit. A user can't get into this state: their first click outside the menu closes it (2026-11-05).
- A button that disables itself when pressed (Restore Default) makes `ax press` print `AXPress failed: -25200` although the press worked. Check the result (`ax rows`, the file) instead of trusting the error.
- A button that opens a modal window (Import…, Export…) doesn't return from `AXPress` while the window is open: run `ax press` in the background (`… &`). A save window needs a path typed on the keyboard (⇧⌘G), only when Cyrano is in front; otherwise close it with `ax press Cancel`.

## VoiceOver

To hear what VoiceOver says, drive it through AppleScript. That needs "Allow VoiceOver to be controlled with AppleScript" in VoiceOver Utility → General; only the user turns it on. It's on when `/private/var/db/Accessibility/.VoiceOverAppleScriptEnabled` exists. Don't check with a `tell application "VoiceOver"` call: it starts VoiceOver.

1. Tell the user VoiceOver will speak aloud. Start it with `open /System/Library/CoreServices/VoiceOver.app`. On first start it shows a welcome window that blocks AppleScript; close it with Use VoiceOver (`osascript -e 'tell application "System Events" to tell process "VoiceOver Quickstart" to click button "Use VoiceOver" of window 1'`).
2. VoiceOver reads the window that has keyboard focus. The panel opens with the keyboard. For Settings, click into its window first (`ax doubleclick` on a static text); then check with `lsappinfo info -only bundleid $(lsappinfo front)`.
3. Each step: `osascript -e 'tell application "VoiceOver"' -e 'tell vo cursor to move right' -e 'delay 1' -e 'return content of last phrase' -e 'end tell'`. Moves: `right`, `left`, `up`, `down`, `into item`, `out of item`, `to first item`. A group or a table is entered with `into item`; in a table `down` also selects the row.
4. Turn VoiceOver off: `osascript -e 'tell application "VoiceOver" to quit'`. Tell the user they can turn the AppleScript setting off.

## If keys didn't arrive

`capture.sh` prints `the panel did not open for TextEdit`, and the permissions are in place. Where the keys went is visible in the system log (local time):

```bash
/usr/bin/log show --last 2m --predicate '(process == "WindowServer" AND eventMessage CONTAINS "Keyboard event") OR (process == "tccd" AND eventMessage CONTAINS "AUTHREQ_RESULT")' --style compact
```

- `destinations for Keyboard event: (<keyboardFocus; TextEdit…>)` — the keys reached TextEdit, but ⌥⌘G didn't fire as a hotkey: WindowServer doesn't pass a hotkey that fired to a window, so there's no line for it. Check that Cyrano is alive and that the shortcut isn't being recorded in Settings. Press the hotkey with `ax key`: System Events presses (`osascript … keystroke`) reach the app but don't always trigger a global hotkey (on 2026-11-02 they triggered it neither for Cyrano nor for a separate probe with `RegisterEventHotKey`).
- `SecurityAgent…` — the password prompt held the focus.
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
