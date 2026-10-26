# tmux-prompt-sidebar

**Run several Claude Code sessions in tmux without losing track of them.**
A sidebar lists every session, window and pane by what you last asked Claude
there, and marks the ones that need you.

![The sidebar: clicking rows to switch windows and sessions, a new prompt renaming its row, and a finished session marked until you look at it](docs/demo/sidebar.gif)

With three or four Claude Code sessions open, tmux's status bar says
`claude claude claude`. Which one was the auth refactor? Which one stopped
twenty minutes ago to ask for a permission? Which finished while you were in
another window? You find out by cycling through them all.

The sidebar answers all three at a glance:

- **Named by what you asked.** Each pane is listed by your latest prompt in it,
  with Claude's own title for the conversation underneath. Send a new prompt
  and the row (and the window's name) follows.
- **`?` Claude is waiting for you**: a question or a permission prompt, in
  yellow, so a stalled session doesn't sit unnoticed.
- **`●` finished since you last looked**, in green, until you go to that pane.
- **`⋯` still working.**
- **One click to get there**, across windows and sessions. Or `j`/`k` and Enter.
- **Split windows too:** each pane gets its own row and mark.
- **Out of the way when it should be.** `prefix + e` hides it everywhere; on a
  narrow client, like a phone over SSH, it steps aside for the normal status
  bar (whose window names are your prompts too).

It's two small Python scripts (standard library only) and three Claude Code
hooks. Nothing runs in the background besides one sidebar pane per window.

## Install

Needs tmux 3.2+ and Python 3.9+ (`python3` on your `PATH`). Linux and macOS.

**1. The sidebar**, with [TPM](https://github.com/tmux-plugins/tpm), in
`~/.tmux.conf`:

```tmux
set -g @plugin 'bilun167/tmux-prompt-sidebar'
```

then `prefix + I`. Without TPM, clone the repo and run `./install.sh`, which
adds `run-shell '/path/to/tmux-prompt-sidebar/sidebar.tmux'` to `~/.tmux.conf`
and reloads tmux.

**2. The Claude Code hooks**, which tell the sidebar what each Claude pane is
doing. Inside Claude Code:

```
/plugin marketplace add bilun167/tmux-prompt-sidebar
/plugin install tmux-prompt-sidebar@tmux-prompt-sidebar
```

Or, without plugins, `./install.sh --hooks` adds the same three hooks to
`~/.claude/settings.json` (needs `jq`; it backs the file up first). Use one or
the other, not both. Sessions already running pick up the hooks after a
restart. Without the hooks the sidebar still works, listing panes by Claude's
own titles.

## Options

Set these in `~/.tmux.conf` before the plugin loads:

| Option | Default | |
|---|---|---|
| `@sidebar_key` | `e` | key after the prefix that toggles the sidebar |
| `@sidebar_min_width` | `120` | narrower clients keep the status bar |
| `@sidebar_width_pct` | `20` | sidebar width, % of the client's width |
| `@sidebar_min`, `@sidebar_max` | `22`, `40` | limits on that width, in columns |
| `@sidebar_on` | `1` | `0` starts with the sidebar off |

The sidebar follows the terminal when it's resized. Drag its border to change
its width; that stays until the terminal is resized again.

## Details

- A pane where Claude has exited back to the shell shows its folder instead
  of the old prompt.
- The hook renames a window after the latest prompt in any of its panes,
  which turns off tmux's automatic renaming for that window.
- **With tmux-resurrect**, restored sidebars come back as plain panes unless
  you add the sidebar to resurrect's processes:
  `set -g @resurrect-processes '"~tmux-sidebar run"'` (alongside any you
  already list).

## How it works

`bin/tmux-claude-hook` runs on Claude Code's `UserPromptSubmit`, `Stop` and
`Notification` hooks. It stores the prompt and a state (`working`, `waiting`,
`done`) as pane options (`@claude_prompt`, `@claude_state`, `@claude_unread`)
and renames the window. Outside tmux it does nothing.

`bin/tmux-sidebar run` is the sidebar: one narrow pane per window, redrawn
from `tmux list-panes -a` once a second or on a click or key. tmux hooks
(`after-new-window`, `client-session-changed`, `client-resized` and others,
at index 90) call `tmux-sidebar ensure`, which adds or removes the current
window's sidebar and turns the status bar off or on.

## Uninstall

Remove the `@plugin` line (or the `run-shell` line) from `~/.tmux.conf`, then
`prefix + e` to close the open sidebars and `tmux set -g status on`. Remove the
Claude Code plugin with `/plugin uninstall tmux-prompt-sidebar`, or the three
`tmux-claude-hook` entries from `~/.claude/settings.json`.

## Development

`python3 -m unittest discover -s tests` runs the tests. `docs/demo/make.sh`
rebuilds the GIF above: a made-up session on a throwaway tmux server, clicked
and typed into by the script, recorded, and rendered with xterm.js, headless
Chromium and ffmpeg.

## Licence

MIT
