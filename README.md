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

1. 在 `~/.claude/settings.json` 中添加 HTTP hooks（PreToolUse、PostToolUse、PermissionRequest、Stop 等）；若该文件不存在会自动创建
2. 安装 statusline 脚本以读取 token/context 数据（即使此前未配置 statusline 也会安装）
3. 修改前先把原 `settings.json` 备份为 `~/.claude/settings.json.bak`；若此前已有 statusline，其原配置另备份到 `~/.claude/statusline-command-original.sh`

> 若 `settings.json` 存在但不是合法 JSON，应用不会改写它，并会在菜单栏面板顶部显示「SETUP FAILED」提示。

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

### 方式一（推荐）：自动脚本

DMG 内附带 `Uninstall.sh`（源码为 `Scripts/uninstall.sh`），运行即可一键卸载：

```bash
bash Scripts/uninstall.sh
```

脚本会依次：退出 app → 从 `settings.json` 移除 ClaudeMonitor 的 hooks（按 url 含 `19806` 识别）→ 恢复原 statusline → 删除临时文件 → 从 `/Applications` 移除 app。

### 方式二：手动

1. 退出 ClaudeMonitor，并从 `Applications` 删除 `ClaudeMonitor.app`
2. 清理 hooks：编辑 `~/.claude/settings.json`，删除 `hooks` 中 url 含 `19806` 的条目（这些条目同时带有 `"_tag": "ClaudeMonitor"` 标记）
3. 恢复 statusline：
   - 若此前配置过 statusline：把 `~/.claude/statusline-command-original.sh` 拷回 `~/.claude/statusline-command.sh`，并将 settings.json 中 `statusLine.command` 改回 `bash ~/.claude/statusline-command.sh`
   - 若此前没有 statusline：删除 settings.json 中的 `statusLine` 字段即可
4. 删除残留文件：`~/.claude/statusline-monitor.sh`、`~/.claude/monitor-status.json`、`~/.claude/monitor-debug.log`（及轮转产生的 `monitor-debug.log.1`）

> 提示：ClaudeMonitor 在首次修改前会把原 `settings.json` 备份为 `~/.claude/settings.json.bak`。若想直接回滚配置改动，用它覆盖回去即可（注意这会一并丢弃备份之后的其它改动）。

完成后**重启 Claude Code** 使改动生效。

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
