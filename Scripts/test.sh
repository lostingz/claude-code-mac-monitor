#!/bin/bash
# ClaudeMonitor 完整功能测试脚本
# 模拟一个真实的 Claude Code 工作会话

HOOK_URL="http://127.0.0.1:19806/hook"
STATUS_FILE="$HOME/.claude/monitor-status.json"
SESSION_ID="test-$(date +%s)"

send_hook() {
    curl -s --max-time 5 -X POST "$HOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$1" > /dev/null 2>&1
}

send_hook_wait() {
    curl -s --max-time 120 -X POST "$HOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$1" 2>/dev/null
}

write_status() {
    cat > "$STATUS_FILE" << STATUSEOF
$1
STATUSEOF
}

echo "=========================================="
echo "  ClaudeMonitor 功能测试"
echo "=========================================="
echo ""
echo "请打开菜单栏 Claude Monitor popover 观察变化"
echo ""
sleep 2

# ============================================
echo "[1/7] 模拟会话开始..."
echo "  → 菜单栏图标应变为绿色"
send_hook "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"$SESSION_ID\",\"cwd\":\"/Users/user/my-project\"}"
sleep 1

write_status "{
  \"session_id\": \"$SESSION_ID\",
  \"model\": {\"id\": \"claude-opus-4-6-max[1m]\", \"display_name\": \"Opus 4.6 (1M context)\"},
  \"cost\": {\"total_cost_usd\": 0.0000, \"total_duration_ms\": 1000},
  \"context_window\": {
    \"total_input_tokens\": 12500,
    \"total_output_tokens\": 350,
    \"context_window_size\": 1000000,
    \"used_percentage\": 1.3,
    \"remaining_percentage\": 98.7
  },
  \"workspace\": {\"current_dir\": \"/Users/user/my-project\", \"project_dir\": \"/Users/user/my-project\"},
  \"rate_limits\": {
    \"five_hour\": {\"used_percentage\": 5.2},
    \"seven_day\": {\"used_percentage\": 12.8}
  }
}"
echo "  ✓ 状态: 工作中 | Context: 1.3% | Rate: 5h 5% / 7d 13%"
sleep 2

# ============================================
echo ""
echo "[2/7] 模拟调用 Read 工具..."
echo "  → 图标应变为蓝色齿轮"
send_hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/Users/user/my-project/src/main.swift\"}}"
sleep 2

send_hook "{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"/Users/user/my-project/src/main.swift\"}}"
echo "  ✓ Tool History 应显示: Read /Users/user/my-project/src/main.swift"
sleep 1

# ============================================
echo ""
echo "[3/7] 模拟调用 Bash 工具..."
echo "  → 图标应再次变蓝"
send_hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"swift build -c release\"}}"
sleep 2

write_status "{
  \"session_id\": \"$SESSION_ID\",
  \"model\": {\"id\": \"claude-opus-4-6-max[1m]\", \"display_name\": \"Opus 4.6 (1M context)\"},
  \"cost\": {\"total_cost_usd\": 0.0842, \"total_duration_ms\": 15000},
  \"context_window\": {
    \"total_input_tokens\": 35200,
    \"total_output_tokens\": 1580,
    \"context_window_size\": 1000000,
    \"used_percentage\": 3.7,
    \"remaining_percentage\": 96.3
  },
  \"workspace\": {\"current_dir\": \"/Users/user/my-project\", \"project_dir\": \"/Users/user/my-project\"},
  \"rate_limits\": {
    \"five_hour\": {\"used_percentage\": 6.1},
    \"seven_day\": {\"used_percentage\": 13.2}
  }
}"

send_hook "{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"swift build -c release\"}}"
echo "  ✓ Context 应更新为 3.7% | Cost: \$0.0842 | Tool Calls: 2"
sleep 1

# ============================================
echo ""
echo "[4/7] 模拟连续调用 Edit + Write 工具..."
send_hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"/Users/user/my-project/src/app.swift\",\"old_string\":\"let x = 1\",\"new_string\":\"let x = 42\"}}"
sleep 1
send_hook "{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Edit\"}"
sleep 0.5

send_hook "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/Users/user/my-project/tests/test.swift\",\"content\":\"import XCTest...\"}}"
sleep 1
send_hook "{\"hook_event_name\":\"PostToolUse\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Write\"}"
echo "  ✓ Tool Calls: 4 | History 应显示: Write, Edit, Bash, Read"
sleep 1

# ============================================
echo ""
echo "[5/7] 模拟 Context 增长到 45%..."

write_status "{
  \"session_id\": \"$SESSION_ID\",
  \"model\": {\"id\": \"claude-opus-4-6-max[1m]\", \"display_name\": \"Opus 4.6 (1M context)\"},
  \"cost\": {\"total_cost_usd\": 1.2450, \"total_duration_ms\": 180000},
  \"context_window\": {
    \"total_input_tokens\": 420000,
    \"total_output_tokens\": 28500,
    \"context_window_size\": 1000000,
    \"used_percentage\": 45.2,
    \"remaining_percentage\": 54.8
  },
  \"workspace\": {\"current_dir\": \"/Users/user/my-project\", \"project_dir\": \"/Users/user/my-project\"},
  \"rate_limits\": {
    \"five_hour\": {\"used_percentage\": 35.6},
    \"seven_day\": {\"used_percentage\": 22.4}
  }
}"
echo "  ✓ 圆环应变为绿色 45% | Cost: \$1.2450 | Duration 更新"
sleep 3

# ============================================
echo ""
echo "[6/7] 模拟权限审批请求..."
echo "  → 应弹出审批窗口！请在弹窗中点击 Allow 或 Deny"
echo "  → 菜单栏图标应变为橙色感叹号"
echo ""

RESPONSE=$(send_hook_wait "{\"hook_event_name\":\"PermissionRequest\",\"session_id\":\"$SESSION_ID\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker rm -f production-db\"}}")

echo ""
echo "  ✓ 你的决策: $RESPONSE"
sleep 1

# ============================================
echo ""
echo "[7/7] 模拟会话结束..."
echo "  → 图标应变回灰色"
send_hook "{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION_ID\"}"
sleep 1
send_hook "{\"hook_event_name\":\"SessionEnd\",\"session_id\":\"$SESSION_ID\"}"

echo "  ✓ 状态: 未连接"
sleep 1

echo ""
echo "=========================================="
echo "  测试完成！"
echo "=========================================="
echo ""
echo "检查清单:"
echo "  [ ] 菜单栏图标颜色变化: 灰→绿→蓝→绿→橙→灰"
echo "  [ ] Popover 显示正确的统计数据"
echo "  [ ] Context 圆环从 1.3% 增长到 45%"
echo "  [ ] Tool History 显示 4 次调用记录"
echo "  [ ] 审批弹窗正确弹出并响应点击"
echo "  [ ] 最终状态回到 未连接/灰色"
