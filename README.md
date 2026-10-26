# tmux-prompt-sidebar

A tree of your tmux sessions and windows on the right of every window, like
an editor's project panel, in place of the status bar. Each pane running
[Claude Code](https://claude.com/claude-code) is listed by your latest prompt
in it, with a mark for whether Claude is working, waiting for you, or finished
since you last looked.

```
▾ main
  1 ● fix the caps lock remap so
  ⋮   it survives a reboot and…
  ⋮   Caps Lock remapping to lef…
  2 ? /kanban-reconcile
  3 ⋯ add the tmux sidebar
  ⋮   TMUX right-side tab tree
  ⋮ ● add a row per pane
  ⋮   Sidebar tab name changes
▾ notes
  1 · ~
```

Two parts, both in this repo:

- **The tmux plugin** (`sidebar.tmux`, `bin/tmux-sidebar`): the sidebar.
- **The Claude Code plugin** (`.claude-plugin/`, `hooks/`, `bin/tmux-claude-hook`):
  hooks that tell tmux what each Claude pane is doing. Without them the
  sidebar still works, showing Claude's own conversation titles and window
  names.

Needs tmux 3.2+ and Python 3.9+ (`python3` on your `PATH`). Linux and macOS.

## Install

**tmux**, with [TPM](https://github.com/tmux-plugins/tpm), in `~/.tmux.conf`:

```tmux
set -g @plugin 'bilun167/tmux-prompt-sidebar'
```

then `prefix + I`. Without TPM, clone the repo and run `./install.sh`, which
adds `run-shell '/path/to/tmux-prompt-sidebar/sidebar.tmux'` to `~/.tmux.conf`
and reloads tmux.

**Claude Code**, inside Claude:

```
/plugin marketplace add bilun167/tmux-prompt-sidebar
/plugin install tmux-prompt-sidebar@tmux-prompt-sidebar
```

Or, without plugins, `./install.sh --hooks` adds the same three hooks to
`~/.claude/settings.json` (needs `jq`; it backs the file up first). Use one or
the other, not both. Claude sessions already running pick up the hooks after a
restart.

## Using it

- Line one of a pane is your latest prompt to Claude in it, wrapped onto two
  lines. The dimmed line under it is Claude's own title for the conversation.
- A window split into panes lists them one under another next to its number,
  each with its own mark. `⋮` runs down all of a window's rows.
- Marks: `⋯` Claude is working, `?` it's waiting for you (a question or a
  permission prompt), `●` it finished since you last looked at that pane.
  `·` means nothing is going on. Landing on the pane clears `●`.
- Once Claude exits and the pane is back at a shell, it shows the pane's
  folder instead.
- Click a row to go to that window and pane, or focus the sidebar and use
  `j`/`k` and Enter (`q` or Esc to leave).
- `prefix + e` turns the sidebar on or off everywhere.
- Clients narrower than 120 columns (a phone, say) don't get the sidebar and
  keep the status bar, whose window names are your prompts too.
- The sidebar is 20% of the terminal's width, between 22 and 40 columns, and
  follows the terminal when it's resized. Drag its border to change it; that
  stays until the terminal is resized again.

The hook renames a window after the latest prompt in any of its panes, which
turns off tmux's automatic renaming for that window.

## Options

Set these in `~/.tmux.conf` before the plugin loads:

| Option | Default | |
|---|---|---|
| `@sidebar_key` | `e` | key after the prefix that toggles the sidebar |
| `@sidebar_min_width` | `120` | narrower clients keep the status bar |
| `@sidebar_width_pct` | `20` | sidebar width, % of the client's width |
| `@sidebar_min`, `@sidebar_max` | `22`, `40` | limits on that width, in columns |
| `@sidebar_on` | `1` | `0` starts with the sidebar off |

## With tmux-resurrect

Sidebars restored by tmux-resurrect come back as plain panes. To restore
them as sidebars, add the sidebar to resurrect's processes:

```tmux
set -g @resurrect-processes '"~tmux-sidebar run"'
```

If a window ends up with two, the next `ensure` (switching windows, say)
removes the extra one.

## How it works

`tmux-claude-hook` runs on Claude Code's `UserPromptSubmit`, `Stop` and
`Notification` hooks. It stores the prompt and a state (`working`, `waiting`,
`done`) as pane options (`@claude_prompt`, `@claude_state`,
`@claude_unread`), and renames the window. It does nothing outside tmux.

`tmux-sidebar run` is the sidebar: one small pane per window, redrawn once a
second from `tmux list-panes -a`. tmux hooks (`after-new-window`,
`client-resized` and others, at index 90) call `tmux-sidebar ensure`, which
adds or removes the current window's sidebar and turns the status bar off or
on.

## Uninstall

Remove the `@plugin` line (or the `run-shell` line) from `~/.tmux.conf`, then
`prefix + e` to close the open sidebars and `tmux set -g status on`. Remove the
Claude Code plugin with `/plugin uninstall tmux-prompt-sidebar`, or the three
`tmux-claude-hook` entries from `~/.claude/settings.json`.

## Licence

MIT
