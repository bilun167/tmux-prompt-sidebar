#!/usr/bin/env bash
# Entry point for TPM (set -g @plugin 'bilun167/tmux-prompt-sidebar'), or
# without TPM: run-shell /path/to/tmux-prompt-sidebar/sidebar.tmux
# Options (set them before this runs; defaults in bin/tmux-sidebar):
#   @sidebar_key         key after the prefix that toggles the sidebar (e)
#   @sidebar_min_width   narrower clients keep the status bar instead (120)
#   @sidebar_width_pct   sidebar width as % of the client (20)
#   @sidebar_min/_max    clamp for that width, in columns (22, 40)
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="'$dir/bin/tmux-sidebar'"

key=$(tmux show -gqv @sidebar_key)
tmux bind "${key:-e}" run-shell -b "$bin toggle"
# Landing on a pane clears its "finished since you last looked" mark
tmux set-hook -g 'session-window-changed[90]' "set -p @claude_unread 0 ; run-shell -b \"$bin ensure\""
tmux set-hook -g 'window-pane-changed[90]' 'set -p @claude_unread 0'
tmux set-hook -g 'after-new-window[90]' "run-shell -b \"$bin ensure\""
tmux set-hook -g 'client-attached[90]' "run-shell -b \"$bin ensure\""
tmux set-hook -g 'client-resized[90]' "run-shell -b \"$bin ensure\""
tmux set-hook -g 'window-resized[90]' "run-shell -b \"$bin fit #{window_id}\""
tmux run-shell -b "$bin ensure"
