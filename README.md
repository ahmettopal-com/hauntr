<p align="center">
  <img src="assets/icon.png" width="128" alt="Hauntr icon" />
</p>

# 👻 Hauntr

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A macOS menu bar app that manages and launches multi-pane [Ghostty](https://ghostty.org) terminal layouts for your development projects.

Define your pane layout visually, assign commands to each pane, and launch everything with one click or from the CLI.

![Demo](assets/demo.gif)

## Features

-   **Menu bar only** — lives in your menu bar, no Dock icon
-   **Visual pane editor** — split panes horizontally/vertically with a canvas preview
-   **Per-pane commands** — assign shell commands to each pane with optional auto-execute
-   **Display names** — friendly names with emoji support for the menu, separate from CLI identifiers
-   **Project groups** — organize projects with drag-and-drop reorderable group headers
-   **Hidden toggle** — hide projects or groups from the menu bar while keeping them accessible via CLI
-   **Duplicate projects** — clone any project with its full pane layout
-   **Launch modes** — "Start here" (current window) or "Start in new window"
-   **Equalize splits** — optionally equalize all pane sizes after launch
-   **CLI tool** — launch layouts, get project paths, and manage projects from the terminal
-   **URL scheme** — `hauntr://` for deep linking into the app
-   **AppleScript generation** — generates two `.applescript` files per project (here & new window) using Ghostty's native API

## Requirements

-   macOS 15.7 (Sequoia) or later
-   [Ghostty](https://ghostty.org) terminal
-   Xcode 16+ (to build from source)

## Build from Source

```bash
git clone https://github.com/ahmettopal-com/hauntr.git
cd hauntr
open Hauntr.xcodeproj
```

Build and run with **Cmd+R** in Xcode. The app appears in your menu bar.

## CLI

Install the CLI from the menu bar: **Hauntr → Install CLI...**

This copies the `hauntr` script to `/usr/local/bin/hauntr` (requires admin password).

### Commands

```
hauntr                      List all projects (hidden projects are excluded)
hauntr <name>               Launch in new window (default)
hauntr <name> --here        Launch in current window
hauntr <name> --window      Launch in new window
hauntr <name> --path        Print project directory path
hauntr <name> --script      Print paths to generated .applescript files
hauntr <name> --edit        Open project in Hauntr app for editing
hauntr --add                Add current directory as a new project
hauntr --uninstall-cli      Remove the CLI from /usr/local/bin
```

Hidden projects are excluded from `hauntr` listing but can still be launched by name.

### Shell Integration

Add a function to your `~/.zshrc` or `~/.bashrc` for a `h` shortcut, to `cd` into project directories or start project `here` in current window / tab:

```bash
function h() {
  if [ "$2" = "win" ]; then
    hauntr "$1" --window
  elif [ "$2" = "here" ]; then
    hauntr "$1" --here
  elif [ "$2" = "cd" ]; then
    cd "$(hauntr "$1" --path)"
  else
    hauntr "$@"
  fi
}
```

Then use `h myproject cd` to jump to a project directory, use `h myproject here` to open project in same window / tab or `h project` to open project in new window.

## URL Scheme

Hauntr registers the `hauntr://` URL scheme for deep linking.

| URL                            | Action                                           |
| ------------------------------ | ------------------------------------------------ |
| `hauntr://edit/<name>`         | Open the edit window for a project               |
| `hauntr://add?path=/some/path` | Open the add project window with path pre-filled |

## AppleScript Generation

Hauntr generates AppleScript files that use Ghostty's native AppleScript API:

1. **Create** a surface configuration with the project's working directory
2. **Open** a new window or reuse the front window (two scripts per project)
3. **Split** panes using `split pane direction "right"/"down"`
4. **Type** commands into each pane using `input text`
5. **Execute** commands by sending `send key "enter"`
6. **Equalize** splits with `perform action "equalize_splits"` (if enabled)
7. **Focus** the first pane

Same-direction nested splits are flattened into sequential split commands for correct ordering.

Two scripts are generated per project — one for reusing the current window and one for opening a new window:

```bash
osascript ~/.config/hauntr/scripts/myproject-here.applescript
osascript ~/.config/hauntr/scripts/myproject-window.applescript
```

## Config Directory

```
~/.config/hauntr/
├── projects.json                           # All projects and groups
└── scripts/
    ├── <project-name>-here.applescript     # Reuse current window
    └── <project-name>-window.applescript   # Open new window
```

`projects.json` stores an ordered array of project items and group headers. The CLI reads this file directly.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Open a pull request

## Credits

Built by [Ahmet Topal](https://ahmettopal.com)

Follow on [𝕏](https://x.com/ahmettopal)

## License

MIT
