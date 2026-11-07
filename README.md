# FuzzyTab

A menu bar app that fuzzy-searches and switches between:

- Brave tabs (AppleScript)
- Rex tabs (the `rex` CLI that ships with Rex)
- Claude Code sessions in the Claude desktop app (session files + `claude://code/continue` deep link)

Press ⌥Tab to open it. Type to filter, ↑/↓ or ⌃N/⌃P to move, Return to switch, Esc to close.
Every space-separated word must match, and the app name is searchable too, so `rex ops` finds Rex tabs in `ops`.

## Settings

Open Settings… from the menu bar icon to turn each app on or off and to set how many entries each app shows (default 10, shared by all apps).
The limit applies after matching, so a search still finds entries past it.

## Build

Needs only the Xcode Command Line Tools.

```sh
make test      # unit tests
make run       # build build/FuzzyTab.app and open it
make install   # copy it to /Applications
build/FuzzyTab.app/Contents/MacOS/FuzzyTab --list   # print every item without the UI
```

## Setup

- **Brave**: on first use macOS asks to let FuzzyTab control Brave. Allow it.
- **Rex**: turn on Settings → Rex Server → Remote Control. Without it, Rex tabs show in the list but switching fails.
