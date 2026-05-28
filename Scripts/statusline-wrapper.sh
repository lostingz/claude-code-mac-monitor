#!/bin/bash
input=$(cat)
echo "$input" > "$HOME/.claude/monitor-status.json"
ORIGINAL="$HOME/.claude/statusline-command-original.sh"
if [ -f "$ORIGINAL" ]; then
    echo "$input" | bash "$ORIGINAL"
fi
