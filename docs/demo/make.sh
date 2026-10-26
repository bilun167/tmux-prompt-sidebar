#!/bin/bash
# Regenerate docs/demo/sidebar.gif: a made-up session on a throwaway tmux
# server (its own HOME and socket). A client attached through `script` is
# recorded while this script clicks rows and types a prompt into it; then
# render.js replays the recording in xterm.js (headless Chromium) frame by
# frame, with a mouse pointer drawn on, and ffmpeg makes the GIF.
# Needs tmux, python3, script (util-linux), node/npm, chromium, ffmpeg.
# Usage: docs/demo/make.sh
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work=$(mktemp -d)
sock=$(mktemp -d /tmp/tps-XXXX)  # short: a socket path can't be long
trap 'TMUX_TMPDIR=$sock tmux kill-server 2>/dev/null || true; [ -n "${KEEP:-}" ] && echo "kept $work" || rm -rf "$work"; rm -rf "$sock"' EXIT
cols=140 rows=30
export HOME=$work TMUX_TMPDIR=$sock
unset TMUX
mkdir -p "$work/acme-api" "$work/blog"
cat > "$HOME/.tmux.conf" <<CONF
set -g default-terminal tmux-256color
set -g mouse on
set -g base-index 1
set -g pane-border-lines heavy
set -g pane-active-border-style fg=colour39
run-shell '$root/sidebar.tmux'
CONF

fake() { echo "exec python3 '$here/fake-claude' '$here/t/$1.txt' ${2:-}"; }
new() { local cmd=$1; shift; tmux "$cmd" -P -F '#{pane_id}' "$@"; }
L=$(new new -d -s acme-api -c "$work/acme-api" -x $cols -y $rows "$(fake tests)")
R=$(new split-window -h -d -t "$L" -c "$work/acme-api" "$(fake ci)")
W2=$(new new-window -d -t acme-api:2 -c "$work/acme-api" "$(fake ratelimit --input)")
W3=$(new new-window -d -t acme-api:3 -c "$work/acme-api" "$(fake uuid)")
new new-window -d -t acme-api:4 -c "$work/acme-api" "env -i HOME='$work' TERM=tmux-256color PS1='\\w \$ ' bash --norc" >/dev/null
B1=$(new new -d -s blog -c "$work/blog" "$(fake post --input)")
B2=$(new new-window -d -t blog:2 -c "$work/blog" "$(fake rss)")

# What tmux-claude-hook and Claude's own titles would have set by now
claude() {  # claude <pane> <prompt> <title> <state> <unread>
  tmux rename-window -t "$1" "${2:0:27}"
  tmux set -p -t "$1" @claude_prompt "$2"
  tmux set -p -t "$1" @claude_state "$4"
  tmux set -p -t "$1" @claude_unread "$5"
  tmux select-pane -t "$1" -T "$3"
}
claude "$R" "why do macOS CI runs miss the cache" "✳ CI cache misses" waiting 0
claude "$L" "write tests for the token refresh flow" "⠐ Token refresh tests" working 0
claude "$W2" "add rate limiting to the /login endpoint" "✳ Login rate limiting" done 1
claude "$W3" "migrate the users table to uuid primary keys" "⠂ UUID primary keys" working 0
claude "$B1" "draft a post about the v2 release" "✳ v2 release post" done 0
claude "$B2" "fix the broken links in the RSS feed" "✳ RSS feed links" done 1
tmux select-window -t acme-api:1
tmux select-pane -t "$L"

# Record an attached client; its input comes from a fifo this script writes to
mkfifo "$work/in"
script -q -f --log-out "$work/ts" --log-timing "$work/timing" \
  -c "stty cols $cols rows $rows; tmux attach -t acme-api" < "$work/in" > /dev/null 2>&1 &
rec=$!
exec 3> "$work/in"
t0=$(date +%s.%N)
: > "$work/clicks"

click() {  # click <text on a row of the sidebar>
  local session sb left top row x y
  session=$(tmux list-clients -F '#{client_session}' | head -1)
  read -r sb left top < <(tmux list-panes -t "$session:" -F '#{pane_id} #{pane_left} #{pane_top} #{@sidebar}' | awk '$4 == 1 {print $1, $2, $3}')
  row=$(tmux capture-pane -p -t "$sb" | grep -n -F "$1" | head -1 | cut -d: -f1)
  x=$((left + 8)) y=$((top + row))
  sleep 0.8  # the pointer moves there in the GIF
  awk -v now="$(date +%s.%N)" -v t0="$t0" -v x=$x -v y=$y 'BEGIN {print now - t0, x, y}' >> "$work/clicks"
  printf '\033[<0;%d;%dM\033[<0;%d;%dm' "$x" "$y" "$x" "$y" >&3
}
typein() {  # typein <text>, then Enter
  local i
  for ((i = 0; i < ${#1}; i++)); do
    printf '%s' "${1:i:1}" >&3
    sleep 0.05
  done
  sleep 0.4
  printf '\r' >&3
}

sleep 2.5
click "add rate limiting"      # go to another window; its ● clears
sleep 1.2
typein "now return 429 with a Retry-After header"
sleep 2.2                      # the row takes the new prompt, ⋯ while it works
click "draft a post"           # another session, while that one works
sleep 4.5                      # it finishes: ● on its row
click "now return 429"         # back to it
sleep 2.5
exec 3>&-
tmux detach-client -s acme-api  # script doesn't end on its own when its input does
wait "$rec"

npm install --silent --prefix "$work/node" puppeteer-core@25.16.0 >/dev/null
curl -sfL -o "$work/xterm.js" https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/lib/xterm.js
curl -sfL -o "$work/xterm.css" https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/css/xterm.css
# Claude Code's ⏺ and ⎿ aren't in DejaVu Sans Mono: Google Fonts subsets with just those
mkdir "$work/frames" "$work/fonts"
for font in "Noto Sans Symbols 2:%E2%8F%BA" "Noto Sans Symbols:%E2%8E%BF"; do
  name=${font%%:*}
  url=$(curl -sf -A "Mozilla/5.0 Chrome/120" "https://fonts.googleapis.com/css2?family=${name// /+}&text=${font#*:}" | grep -o 'https://[^)]*' | head -1)
  curl -sfL -A "Mozilla/5.0 Chrome/120" -o "$work/fonts/$name.font" "$url"
done
NODE_PATH="$work/node/node_modules" node "$here/render.js" "$work" $cols $rows 12
ffmpeg -loglevel error -y -framerate 12 -i "$work/frames/%05d.png" \
  -vf "split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
  -loop 0 "$here/sidebar.gif"
echo "wrote $here/sidebar.gif ($(du -h "$here/sidebar.gif" | cut -f1))"
