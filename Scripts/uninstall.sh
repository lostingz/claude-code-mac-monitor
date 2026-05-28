#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  ClaudeMonitor Uninstaller"
echo "============================================"
echo ""

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

# Step 1: Quit app
echo "[1/4] Stopping ClaudeMonitor..."
pkill -f "ClaudeMonitor" 2>/dev/null && echo "  ✓ App stopped" || echo "  - App not running"

# Step 2: Remove hooks from settings.json (using macOS built-in osascript/JXA)
echo ""
echo "[2/4] Removing hooks from settings.json..."
if [ -f "$SETTINGS" ]; then
    osascript -l JavaScript -e "
        var fm = $.NSFileManager.defaultManager;
        var path = '$SETTINGS';
        var data = $.NSData.alloc.initWithContentsOfFile(path);
        var str = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
        var settings = JSON.parse(str);

        var hooks = settings.hooks || {};
        var cleaned = {};
        for (var event in hooks) {
            var groups = hooks[event];
            if (!Array.isArray(groups)) { cleaned[event] = groups; continue; }
            var filtered = groups.filter(function(g) {
                var hlist = g.hooks || [];
                return !hlist.every(function(h) {
                    return h.url && h.url.indexOf('19806') !== -1;
                });
            });
            if (filtered.length > 0) cleaned[event] = filtered;
        }

        if (Object.keys(cleaned).length > 0) {
            settings.hooks = cleaned;
        } else {
            delete settings.hooks;
        }

        var out = JSON.stringify(settings, null, 2);
        var nsStr = $.NSString.alloc.initWithUTF8String(out);
        nsStr.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
    " 2>/dev/null && echo "  ✓ Hooks removed" || echo "  ⚠ Failed to clean hooks (edit ~/.claude/settings.json manually)"
else
    echo "  - No settings.json found"
fi

# Step 3: Restore original statusline
echo ""
echo "[3/4] Restoring statusline..."
ORIGINAL="$CLAUDE_DIR/statusline-command-original.sh"
if [ -f "$ORIGINAL" ]; then
    cp "$ORIGINAL" "$CLAUDE_DIR/statusline-command.sh"

    osascript -l JavaScript -e "
        var path = '$SETTINGS';
        var data = $.NSData.alloc.initWithContentsOfFile(path);
        var str = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
        var settings = JSON.parse(str);
        settings.statusLine = {
            type: 'command',
            command: 'bash $CLAUDE_DIR/statusline-command.sh'
        };
        var out = JSON.stringify(settings, null, 2);
        var nsStr = $.NSString.alloc.initWithUTF8String(out);
        nsStr.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
    " 2>/dev/null && echo "  ✓ Statusline restored" || echo "  ⚠ Failed to restore statusline"

    rm -f "$ORIGINAL"
    rm -f "$CLAUDE_DIR/statusline-monitor.sh"
else
    echo "  - No original statusline backup found"
fi

# Step 4: Clean up files
echo ""
echo "[4/4] Cleaning up..."
rm -f "$CLAUDE_DIR/monitor-status.json"
rm -f "$CLAUDE_DIR/monitor-debug.log"
echo "  ✓ Temp files removed"

APP_PATH="/Applications/ClaudeMonitor.app"
if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
    echo "  ✓ App removed from /Applications"
else
    echo "  - App not found in /Applications"
fi

echo ""
echo "============================================"
echo "  Uninstall complete!"
echo "  Restart Claude Code for changes to"
echo "  take effect."
echo "============================================"
