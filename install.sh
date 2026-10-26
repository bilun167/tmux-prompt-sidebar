#!/bin/bash
# Install without TPM: add this checkout's sidebar.tmux to ~/.tmux.conf, and
# with --hooks also the Claude Code hooks to ~/.claude/settings.json (skip
# --hooks if you installed the Claude Code plugin; it brings its own).
# A file that changes gets a dated backup first. Safe to run again; reloads a
# running tmux. --hooks needs jq. Works with macOS's bash 3.2.
# Usage: ./install.sh [--hooks]
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
stamp=$(date +%Y%m%d-%H%M%S)

backup() {  # keeps the first backup of a run (or of another installer this second)
  if [ -e "$1" ] && [ ! -e "$1.bak.$stamp" ]; then
    cp -p "$1" "$1.bak.$stamp" && echo "backed up $1 to $1.bak.$stamp"
  fi
}

line="run-shell '$dir/sidebar.tmux'"
if ! grep -qF "$line" ~/.tmux.conf 2>/dev/null; then
  backup ~/.tmux.conf
  printf '\n# tmux-prompt-sidebar\n%s\n' "$line" >> ~/.tmux.conf
  echo "added the sidebar to ~/.tmux.conf"
fi

if [ "${1:-}" = --hooks ]; then
  settings=~/.claude/settings.json
  hook="$dir/bin/tmux-claude-hook"
  if ! grep -qs tmux-claude-hook "$settings"; then
    backup "$settings"
    mkdir -p ~/.claude
    [ -s "$settings" ] || echo '{}' > "$settings"
    jq --arg h "'$hook'" '
      def add(ev; arg): .hooks[ev] += [{"hooks":[{"type":"command","command":"\($h) \(arg) || true","timeout":5}]}];
      add("UserPromptSubmit"; "prompt") | add("Stop"; "stop") | add("Notification"; "notify")' \
      "$settings" > "$settings.new" && mv "$settings.new" "$settings"
    echo "added the hooks to $settings (Claude sessions already running pick them up after a restart)"
  fi
fi

if tmux has-session 2>/dev/null; then  # a server is running (info needs a client)
  tmux source-file ~/.tmux.conf
  echo "reloaded tmux"
fi
