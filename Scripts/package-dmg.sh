#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="ClaudeMonitor"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}"
APP_DIR="${APP_NAME}.app"
DMG_TEMP="build-dmg"
DMG_FILE="${DMG_NAME}.dmg"

echo "============================================"
echo "  ClaudeMonitor DMG Packager v${VERSION}"
echo "============================================"
echo ""

# Step 1: Build release binary
echo "[1/5] Building release binary ($(uname -m))..."
swift build -c release 2>&1 | tail -3
BINARY=".build/release/ClaudeMonitor"
echo "  ✓ Universal binary built"

# Step 2: Create .app bundle
echo ""
echo "[2/5] Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/"
cp Info.plist "$APP_DIR/Contents/"
cp Scripts/statusline-wrapper.sh "$APP_DIR/Contents/Resources/"
chmod +x "$APP_DIR/Contents/Resources/statusline-wrapper.sh"
echo "  ✓ App bundle created"

# Step 3: Ad-hoc code sign
echo ""
echo "[3/5] Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR" 2>&1
echo "  ✓ Code signed"

# Step 4: Create DMG
echo ""
echo "[4/5] Creating DMG installer..."
rm -rf "$DMG_TEMP"
rm -f "$DMG_FILE"

mkdir -p "$DMG_TEMP"
cp -R "$APP_DIR" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"
cp Scripts/uninstall.sh "$DMG_TEMP/Uninstall.sh"

# Create a README for the DMG
cat > "$DMG_TEMP/README.txt" << 'READMEEOF'
ClaudeMonitor - Claude Code Menu Bar Monitor
=============================================

安装步骤:
  1. 将 ClaudeMonitor.app 拖到右侧 Applications 文件夹
  2. 从 Applications 中打开 ClaudeMonitor
  3. 首次启动会自动配置 Claude Code hooks，无需手动操作

首次打开安全提示:
  由于非 App Store 分发，macOS 会提示"无法验证开发者"。
  解决: 右键 ClaudeMonitor.app → 选择"打开" → 对话框中点击"打开"
  (仅首次需要，后续正常启动即可)

功能:
  - 菜单栏实时显示 Claude Code 工作状态
  - Context window / token 用量监控
  - 工具调用历史记录
  - 权限审批弹窗 (无需切换到终端)
  - Rate limit 追踪

系统要求:
  - macOS 14.0 (Sonoma) 或更高版本
  - Claude Code CLI 已安装
  - 当前仅支持 Apple Silicon (M1/M2/M3/M4)

注意事项:
  - Hooks 在运行中的 Claude Code 会话不会立即生效，需开启新会话
  - 应用监听本地端口 19806，请确保未被占用

卸载:
  1. 退出 ClaudeMonitor
  2. 删除 Applications 中的 ClaudeMonitor.app
  3. 编辑 ~/.claude/settings.json 删除含 "_tag":"ClaudeMonitor" 的条目

详细文档: https://github.com/your-repo/claude-code-mac-tool
READMEEOF

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_FILE" 2>&1 | grep -v "^$"

echo "  ✓ DMG created"

# Step 5: Cleanup
echo ""
echo "[5/5] Cleanup..."
rm -rf "$DMG_TEMP"
echo "  ✓ Done"

# Summary
echo ""
echo "============================================"
DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
echo "  Output: $DMG_FILE ($DMG_SIZE)"
echo ""
echo "  Architecture: $(uname -m)"
echo "  Signed: Ad-hoc"
echo "  macOS: 14.0+"
echo "============================================"
echo ""
echo "Test: open $DMG_FILE"
