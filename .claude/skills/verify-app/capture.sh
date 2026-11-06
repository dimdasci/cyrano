#!/bin/zsh
# Puts the text into a TextEdit document, selects it and presses ⌥⌘G, then waits until the
# panel shows that text. Presses keys only when they go to TextEdit:
# - Cyrano's windows are closed first: its panel takes the keys without becoming the front app,
#   so System Events would still name TextEdit;
# - a Keychain prompt (SecurityAgent) takes the keys too, so it waits until the prompt is gone;
# - TextEdit must be the front app.
#
#   capture.sh "<text to check>"

set -u
fail() { echo "$1" >&2; exit 1; }
lost="Cyrano has lost its permissions (a new build): the user resets them and grants Accessibility \
and Screen Recording again, see Permissions in SKILL.md"
front() { osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'; }

.build/ax close >/dev/null
[[ -z $(.build/ax windows) ]] || fail "Cyrano still has windows open; not pressing keys"
for _ in {1..60}; do pgrep -xq SecurityAgent || break; sleep 1; done
pgrep -xq SecurityAgent && fail "a Keychain or password prompt is open; not pressing keys"

started=$(date '+%Y-%m-%d %H:%M:%S')
file=${TMPDIR:-/tmp}/cyrano-verify.txt
printf '%s' "$1" > "$file"
osascript -e 'tell application "TextEdit" to close every document saving no' >/dev/null 2>&1
open -a TextEdit "$file"
sleep 1.5
osascript -e 'tell application "TextEdit" to activate' -e 'delay 0.5'
[[ $(front) == TextEdit ]] || fail "TextEdit is not in front ($(front)); not pressing keys"
# Not System Events keystrokes: they reach TextEdit but don't always trigger the global hot key.
.build/ax key a command >/dev/null
sleep 0.3
.build/ax key g option command >/dev/null
sleep 2
# A new build has a new ad-hoc signature, and macOS drops both of Cyrano's own permissions
# (see Permissions in SKILL.md). Without Accessibility the hotkey still opens the panel, but
# without the selected text; without Screen Recording Context is silently not read. Cyrano logs
# both when it captures.
.build/ax tree Proofreading 2>/dev/null | grep -q "Accessibility not granted" \
  && fail "No Accessibility. $lost"
/usr/bin/log show --start "$started" --style compact \
  --predicate 'subsystem == "io.github.dimdasci.cyrano" AND category == "capture"' \
  | grep -q "screenRecording=false" && fail "No Screen Recording. $lost"
[[ $(.build/ax windows | head -n 1) == "Proofreading — TextEdit" ]] \
  || fail "the panel did not open for TextEdit"
.build/ax wait "${1:0:30}" 10 >/dev/null || fail "the panel has other text"
echo "panel open with the text"
