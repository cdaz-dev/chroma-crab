# chroma-crab

[![test](https://github.com/cdaz-dev/chroma-crab/actions/workflows/test.yml/badge.svg)](https://github.com/cdaz-dev/chroma-crab/actions/workflows/test.yml)

A different crab colour for every Claude Code window.

![Three Claude Code windows side by side with a coral, a green and a purple crab](docs/windows.png)

I usually have three or four Claude Code sessions open at once, and they all look identical, so I kept typing into the wrong one. chroma-crab is a small launcher that gives each new window a colour no other open window is using. The crab, the prompt box and the context bar at the bottom all take that colour. When you close a window, its colour goes back in the pool.

It runs on macOS, Linux and Windows.

## Install

macOS and Linux. The status line needs [jq](https://jqlang.org) (`brew install jq` on a Mac).

```sh
git clone https://github.com/cdaz-dev/chroma-crab
cd chroma-crab
./install.sh
```

Windows, in PowerShell:

```powershell
git clone https://github.com/cdaz-dev/chroma-crab
cd chroma-crab
powershell -ExecutionPolicy Bypass -File install.ps1
```

Open a new terminal and run `claude` like you always do. If you open Claude Code from a keybind, log out and back in once so the keybind picks up the change.

## Keybinds and launchers

You don't have to change any of your keybinds. The installer puts a small stand-in called `claude` ahead of the real one on your PATH, and the stand-in hands off to chroma-crab. A keybind, a terminal profile or an app launcher that runs `claude` will get a coloured crab the same way your shell does.

- macOS and Linux: the stand-in is a shell script in `~/.local/share/chroma-crab/bin`. The installer adds that folder to the front of PATH in your shell startup files. On Linux it also adds it to `~/.config/environment.d/`, which is where many desktop sessions get the PATH their keybinds use.
- Windows: the stand-in is a `claude.exe` that the installer compiles from `windows/claude-shim.cs` with the C# compiler built into Windows. It has to be an .exe because Windows Terminal profiles, and other programs that start `claude` directly, only look for `claude.exe`. It goes at the front of your user PATH. Windows reads the system PATH before the user one, so if Claude Code was installed for all users, the stand-in can't get in front of it and you'll want to point things at `chroma-crab` instead.

A keybind that points at the full path of the real binary skips the stand-in. Change it to plain `claude`, or to `chroma-crab`.

Some calls go straight to the real Claude Code without a colour: subcommands like `claude mcp` or `claude update`, print mode (`claude -p`), and any `claude` started from inside a session that already has one. Anything else you pass, like `claude --resume`, goes through unchanged.

If you'd rather leave `claude` alone, install with `./install.sh --no-shim` (or `install.ps1 -NoShim`) and type `chroma-crab` when you want a colour.

## How it works

Claude Code reads custom themes from `~/.claude/themes/`, and the crab is drawn with a theme key called `clawd_body`. This repo ships ten themes in Tokyo Night colours: coral, orange, yellow, green, teal, cyan, blue, purple, pink and silver. Each one sets the crab and the prompt border.

A theme is normally a global setting. `claude --settings <file>` loads extra settings for one process only, so chroma-crab picks a free colour, writes a tiny settings file for it, and starts Claude Code with that file. Those settings sit on top of your own `settings.json`, and the rest of your config is left alone.

Each window claims its colour with a small file holding its process ID. On every launch chroma-crab clears out claims whose process has died, so a window that crashed doesn't keep its colour forever. If all ten are in use, the next window borrows one at random.

## The status line

chroma-crab also sets a status line. It shows the model, the folder you're in, and a 20-cell bar of how full the context window is, drawn in the window's crab colour. The percentage turns amber at 70% and red at 90%.

If you already have a status line you like, turn this one off with `CHROMA_CRAB_STATUSLINE=0` (on Windows, `$env:CHROMA_CRAB_STATUSLINE = '0'`).

## Options

| Variable | Effect |
| --- | --- |
| `CHROMA_CRAB_COLOURS` | Theme names to hand out, in order, separated by spaces. Defaults to all ten. |
| `CHROMA_CRAB_STATUSLINE` | Set to `0` to keep your own status line. |
| `CLAUDE_CONFIG_DIR` | Used if you've moved Claude Code's config folder. |

## Adding a colour

Copy any file in `themes/`, change the hex values, and save it as `~/.claude/themes/crab-<name>.json`. Then list it in `CHROMA_CRAB_COLOURS`. Themes can override plenty of other keys as well, so you can tint more of the interface if you want.

The crab themes also show up in Claude Code's `/theme` menu. Picking one there saves it as your global theme. chroma-crab windows still get their own colour, but anything that skips chroma-crab will use the one you picked.

## Tests

`test/run.sh` and `test/run.ps1` run the launcher against a fake `claude`, so they need no install or login. They check that two windows get different colours, that a crashed window's colour is freed, that plain `claude` reaches chroma-crab through the stand-in, and that the status line draws the right bar. CI runs them on Ubuntu, macOS with its stock bash 3.2, Windows PowerShell 5.1 and PowerShell 7.

## Uninstall

From the repo folder:

```sh
./install.sh --uninstall
```

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

This removes the scripts, the stand-in, the crab themes and the PATH lines the installer added.

## License

MIT
