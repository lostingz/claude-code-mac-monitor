# ClaudeMonitor

macOS 菜单栏应用，实时监控 Claude Code 工作状态。

## 功能

- **实时状态** — 菜单栏图标颜色反映 Claude Code 当前状态（工作中 / 空闲 / 等待审批 / 调用工具）
- **Context 监控** — 圆环动画展示 context window 使用百分比、input/output token 计数
- **费用追踪** — 当前会话的 API 费用、时长、工具调用次数
- **Rate Limit** — 5 小时 / 7 天用量百分比
- **工具日志** — 最近工具调用记录，终端风格展示
- **审批弹窗** — Claude Code 需要权限时弹出桌面窗口，直接点击 Allow / Deny，无需切换到终端

## 安装

### 方式一：DMG 安装

1. 双击打开 `ClaudeMonitor-1.0.0.dmg`
2. 将 `ClaudeMonitor.app` 拖到 `Applications` 文件夹
3. 从 Applications 中打开 ClaudeMonitor

### 方式二：源码编译

```bash
git clone https://github.com/lostingz/claude-code-mac-monitor.git
cd claude-code-mac-monitor
bash Scripts/build.sh
open ClaudeMonitor.app
```

## 首次启动

应用首次启动时会自动完成以下配置，无需手动操作：

1. 在 `~/.claude/settings.json` 中添加 HTTP hooks（PreToolUse、PostToolUse、PermissionRequest、Stop 等）
2. 包装现有 statusline 脚本以读取 token/context 数据
3. 备份原有 statusline 配置到 `~/.claude/statusline-command-original.sh`

**注意：hooks 在运行中的 Claude Code 会话不会立即生效，需要开启新会话。**

## macOS 安全提示

由于应用使用 ad-hoc 签名（非 Apple Developer 证书），首次打开时 macOS 会提示 **"无法验证开发者"**。

### 解决方法

**方法一（推荐）：** 右键点击 `ClaudeMonitor.app` → 选择「打开」→ 在弹出对话框中点击「打开」

**方法二：** 系统设置 → 隐私与安全性 → 向下滚动找到"ClaudeMonitor 已被阻止"→ 点击「仍要打开」

此提示只出现一次，后续启动不会再弹出。

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Claude Code CLI 已安装
- 当前 DMG 仅包含 **arm64 (Apple Silicon)** 版本。Intel Mac 用户需要从源码编译：
  ```bash
  bash Scripts/build.sh
  ```

## 架构

```
Claude Code ──HTTP hooks──→ ClaudeMonitor.app (127.0.0.1:19806)
             ──statusline──→ ~/.claude/monitor-status.json ──FSEvents──→ ClaudeMonitor.app
```

- **HTTP Hooks** — 实时接收工具调用、权限请求、会话生命周期事件
- **Statusline 文件** — 读取 token/context/cost/rate-limit 数据
- **PermissionRequest Hook** — 拦截权限请求，弹出桌面审批窗口，返回决策给 Claude Code

## 项目结构

```
Sources/ClaudeMonitor/
├── ClaudeMonitorApp.swift          # 应用入口、NSStatusItem、popover
├── AppState.swift                  # @Observable 状态存储
├── Models/
│   ├── StatusLineData.swift        # Statusline JSON 模型
│   └── HookEvent.swift             # Hook 事件模型、审批请求
├── Services/
│   ├── HookServer.swift            # NWListener HTTP 服务器
│   ├── StatusFileWatcher.swift     # 文件监听
│   └── SetupService.swift          # 自动安装 hooks
└── Views/
    ├── MenuBarPopover.swift         # 主面板 UI
    ├── ContextGaugeView.swift       # Context 圆环
    └── ApprovalPanel.swift          # 审批弹窗
```

## 卸载

1. 退出 ClaudeMonitor
2. 从 Applications 删除 `ClaudeMonitor.app`
3. 清理 hooks（二选一）：
   - 编辑 `~/.claude/settings.json`，删除所有包含 `"_tag": "ClaudeMonitor"` 的 hook 条目
   - 或删除 `~/.claude/settings.json` 中 hooks 部分里 url 包含 `19806` 的条目
4. 恢复 statusline：将 `~/.claude/statusline-command-original.sh` 重命名为 `~/.claude/statusline-command.sh`，并将 settings.json 中 statusLine.command 改回 `bash ~/.claude/statusline-command.sh`

## 打包

```bash
# 构建 .app
bash Scripts/build.sh

# 打包 DMG
bash Scripts/package-dmg.sh

# 运行功能测试
bash Scripts/test.sh
```

## 调试

应用日志写入 `~/.claude/monitor-debug.log`，可用于排查 hook 通信问题。
