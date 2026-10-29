#!/bin/zsh
# Puts the text into a TextEdit document, selects it and presses ⌥⌘G, then waits until the
# panel shows that text. Stops if TextEdit is not in front, so the hotkey never captures text
# from another app.
#
#   capture.sh "<text to check>"

set -u
file=${TMPDIR:-/tmp}/cyrano-verify.txt
printf '%s' "$1" > "$file"
osascript -e 'tell application "TextEdit" to close every document saving no' >/dev/null 2>&1
open -a TextEdit "$file"
sleep 1.5
osascript -e 'tell application "TextEdit" to activate' -e 'delay 0.5'
front=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')
if [[ $front != TextEdit ]]; then
  echo "TextEdit is not in front ($front); not pressing the hotkey" >&2
  exit 1
fi
osascript -e 'tell application "System Events" to keystroke "a" using command down' -e 'delay 0.3' \
  -e 'tell application "System Events" to keystroke "g" using {option down, command down}'
sleep 2
if [[ $(.build/ax windows | head -n 1) != "Proofreading — TextEdit" ]]; then
  echo "the panel did not open for TextEdit" >&2
  exit 1
fi
.build/ax wait "${1:0:30}" 10 >/dev/null || { echo "the panel has other text" >&2; exit 1; }
echo "panel open with the text"
