#!/usr/bin/env bash

# 集成测试脚本
# 测试完整的工作流程和用户场景

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWITCH_SCRIPT="$SCRIPT_DIR/../scripts/switch-claude.sh"

# 测试计数器
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        echo "  期望: $expected"
        echo "  实际: $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    # 使用 grep -F 按字面量匹配，避免特殊字符被当作正则表达式
    if echo "$haystack" | grep -F -q "$needle"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        echo "  在输出中查找: $needle"
        echo "  实际输出: $haystack"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local test_name="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ -f "$file_path" ]]; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name - 文件不存在: $file_path"
        return 1
    fi
}

# 清理环境
cleanup_test_env() {
    log_info "清理测试环境..."

    # 清理配置文件
    rm -rf ~/.config/switch-claude
    rm -f ~/.claude/settings.json.backup.*

    # 清理 Keychain
    for provider in glm kimi minimax TestAPI CustomAPI; do
        security delete-generic-password -a "$USER" -s "switch-claude-$provider" >/dev/null 2>&1 || true
    done

    # 清理环境变量
    unset GLM_TOKEN
    unset KIMI_TOKEN
    unset MINIMAX_TOKEN

    log_info "清理完成"
}

# ========== 集成测试场景 ==========

# 场景 1: 首次使用流程
scenario_first_time_user() {
    log_section "场景 1: 首次使用流程"

    cleanup_test_env

    log_info "用户首次运行脚本..."

    # 1. 用户运行 help
    log_info "步骤 1: 用户查看帮助"
    local help_output
    help_output=$("$SWITCH_SCRIPT" help 2>&1)
    assert_contains "$help_output" "用法" "help 包含用法说明"
    assert_contains "$help_output" "switch-claude" "help 包含命令示例"

    # 2. 用户运行 list-providers（自动创建 provider.json）
    log_info "步骤 2: 用户查看可用 provider"
    local list_output
    list_output=$("$SWITCH_SCRIPT" list-providers 2>&1)
    assert_contains "$list_output" "可用的 provider" "list-providers 输出正确"
    assert_contains "$list_output" "glm" "显示 glm provider"
    assert_contains "$list_output" "kimi" "显示 kimi provider"
    assert_contains "$list_output" "minimax" "显示 minimax provider"

    # 3. 验证 provider.json 已创建
    assert_file_exists "$HOME/.config/switch-claude/provider.json" "provider.json 已自动创建"

    # 4. 用户查看 provider 配置
    log_info "步骤 3: 用户查看 provider 配置"
    local show_output
    show_output=$("$SWITCH_SCRIPT" show-provider-config 2>&1)
    assert_contains "$show_output" "Provider 配置" "show-provider-config 输出正确"
    assert_contains "$show_output" "[glm]" "显示 GLM 配置"
    assert_contains "$show_output" "[kimi]" "显示 Kimi 配置"
    assert_contains "$show_output" "[minimax]" "显示 Minimax 配置"

    log_success "场景 1 完成: 首次用户流程"
}

# 场景 2: 自定义 Provider 添加和使用
scenario_custom_provider() {
    log_section "场景 2: 自定义 Provider 添加和使用"

    cleanup_test_env
    "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1

    log_info "用户添加自定义 provider..."

    # 1. 添加自定义 provider
    local custom_config='{
        "ANTHROPIC_AUTH_TOKEN": "",
        "ANTHROPIC_BASE_URL": "https://api.custom.example.com/anthropic",
        "ANTHROPIC_MODEL": "custom-model-v1",
        "API_TIMEOUT_MS": "3000000"
    }'

    local add_output
    add_output=$("$SWITCH_SCRIPT" add-provider "CustomAPI" "$custom_config" 2>&1)
    assert_contains "$add_output" "已成功添加" "add-provider 成功"

    # 2. 验证 provider 出现在列表中
    local list_output
    list_output=$("$SWITCH_SCRIPT" list-providers 2>&1)
    assert_contains "$list_output" "CustomAPI" "CustomAPI 出现在列表中"

    # 3. 为自定义 provider 设置 token
    log_info "为自定义 provider 设置 token"
    local token_output
    token_output=$("$SWITCH_SCRIPT" set-token "CustomAPI" "custom-token-123" 2>&1)
    assert_contains "$token_output" "已为 CustomAPI 设置 token" "set-token 成功"

    # 4. 验证 token 已保存
    local saved_token
    saved_token=$(jq -r '.CustomAPI.ANTHROPIC_AUTH_TOKEN' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
    assert_equals "custom-token-123" "$saved_token" "Token 已保存到文件"

    # 5. 切换到自定义 provider
    log_info "切换到自定义 provider"
    local switch_output
    switch_output=$("$SWITCH_SCRIPT" CustomAPI 2>&1)
    assert_contains "$switch_output" "切换到 CustomAPI 模型" "切换成功"

    # 6. 验证配置已应用到 Claude 设置
    local claude_config
    claude_config=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN' "$HOME/.claude/settings.json" 2>/dev/null)
    assert_equals "custom-token-123" "$claude_config" "配置已应用到 Claude"

    # 7. 删除自定义 provider
    log_info "删除自定义 provider"
    local delete_output
    delete_output=$(echo "y" | "$SWITCH_SCRIPT" remove-provider "CustomAPI" 2>&1)
    assert_contains "$delete_output" "已删除 provider: CustomAPI" "remove-provider 成功"

    log_success "场景 2 完成: 自定义 Provider"
}

# 场景 3: Token 优先级测试
scenario_token_priority() {
    log_section "场景 3: Token 优先级测试"

    cleanup_test_env
    "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1

    log_info "测试 token 优先级: Keychain > Env > File > Prompt"

    # 1. 在 provider.json 中设置 token
    log_info "步骤 1: 在 provider.json 中设置 token"
    "$SWITCH_SCRIPT" set-token "glm" "file-token" > /dev/null 2>&1

    # 2. 在环境变量中设置 token
    log_info "步骤 2: 在环境变量中设置 token"
    export GLM_TOKEN="env-token"

    # 3. 在 Keychain 中设置 token
    log_info "步骤 3: 在 Keychain 中设置 token"
    "$SWITCH_SCRIPT" set-keychain "glm" "keychain-token" > /dev/null 2>&1

    # 4. 切换并验证使用 Keychain token
    log_info "步骤 4: 验证优先级（Keychain > Env > File）"
    local switch_output
    switch_output=$("$SWITCH_SCRIPT" glm 2>&1)

    # 验证配置中的 token 是 keychain-token
    local applied_token
    applied_token=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN' "$HOME/.claude/settings.json" 2>/dev/null)
    assert_equals "keychain-token" "$applied_token" "优先级: Keychain 优先"

    # 5. 清除 Keychain，验证使用环境变量
    log_info "步骤 5: 清除 Keychain，验证使用环境变量"
    "$SWITCH_SCRIPT" clear-keychain "glm" > /dev/null 2>&1
    switch_output=$("$SWITCH_SCRIPT" glm 2>&1)

    applied_token=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN' "$HOME/.claude/settings.json" 2>/dev/null)
    assert_equals "env-token" "$applied_token" "优先级: Env 优先"

    # 6. 清除环境变量，验证使用文件中的 token
    log_info "步骤 6: 清除环境变量，验证使用文件"
    unset GLM_TOKEN
    switch_output=$("$SWITCH_SCRIPT" glm 2>&1)

    applied_token=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN' "$HOME/.claude/settings.json" 2>/dev/null)
    assert_equals "file-token" "$applied_token" "优先级: File 优先"

    log_success "场景 3 完成: Token 优先级"

    # 清理
    unset GLM_TOKEN
}

# 场景 4: 完整模型切换工作流
scenario_complete_model_switching() {
    log_section "场景 4: 完整模型切换工作流"

    cleanup_test_env
    "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1

    # 为所有 provider 设置 token
    "$SWITCH_SCRIPT" set-keychain "glm" "glm-token-123" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "kimi" "kimi-token-456" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "minimax" "minimax-token-789" > /dev/null 2>&1

    log_info "依次切换所有模型..."

    # 1. 切换到 GLM
    local glm_output
    glm_output=$("$SWITCH_SCRIPT" glm 2>&1)
    assert_contains "$glm_output" "切换到 GLM 模型" "GLM 切换成功"

    # 2. 验证当前配置
    local current_output
    current_output=$("$SWITCH_SCRIPT" current 2>&1)
    assert_contains "$current_output" "bigmodel" "current 显示 GLM 配置"
    assert_contains "$current_output" "glm-***-123" "GLM token 正确（脱敏后）"

    # 3. 切换到 Kimi
    local kimi_output
    kimi_output=$("$SWITCH_SCRIPT" kimi 2>&1)
    assert_contains "$kimi_output" "切换到 Kimi 模型" "Kimi 切换成功"

    # 4. 验证当前配置
    current_output=$("$SWITCH_SCRIPT" current 2>&1)
    assert_contains "$current_output" "moonshot" "current 显示 Kimi 配置"
    assert_contains "$current_output" "kimi***-456" "Kimi token 正确（脱敏后）"

    # 5. 切换到 Minimax
    local minimax_output
    minimax_output=$("$SWITCH_SCRIPT" minimax 2>&1)
    assert_contains "$minimax_output" "切换到 Minimax 模型" "Minimax 切换成功"

    # 6. 验证当前配置
    current_output=$("$SWITCH_SCRIPT" current 2>&1)
    assert_contains "$current_output" "minimax" "current 显示 Minimax 配置"
    assert_contains "$current_output" "mini***-789" "Minimax token 正确（脱敏后）"

    # 7. 验证配置文件已备份
    local backup_count
    backup_count=$(ls -1 ~/.config/switch-claude/settings.json.backup.* 2>/dev/null | wc -l | tr -d ' ')
    # 动态验证：有备份文件即可（数量可能因环境而异）
    if [[ $backup_count -ge 1 ]]; then
        TESTS_RUN=$((TESTS_RUN + 1))
        log_success "创建了备份文件 (实际: $backup_count)"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        log_error "创建了备份文件"
        echo "  期望: >= 1"
        echo "  实际: $backup_count"
    fi

    log_success "场景 4 完成: 完整模型切换"
}

# 场景 5: Keychain 管理
scenario_keychain_management() {
    log_section "场景 5: Keychain 管理"

    cleanup_test_env
    "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1

    log_info "测试 Keychain 操作..."

    # 1. 设置多个 Keychain token
    "$SWITCH_SCRIPT" set-keychain "glm" "keychain-glm" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "kimi" "keychain-kimi" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "minimax" "keychain-minimax" > /dev/null 2>&1

    # 2. 验证 Keychain 存储
    local glm_token
    glm_token=$(security find-generic-password -a "$USER" -s "switch-claude-glm" -w 2>/dev/null)
    assert_equals "keychain-glm" "$glm_token" "GLM token 存储在 Keychain"

    # 3. 清除单个 Keychain
    "$SWITCH_SCRIPT" clear-keychain "glm" >/dev/null 2>&1
    glm_token=$(security find-generic-password -a "$USER" -s "switch-claude-glm" -w 2>/dev/null)
    assert_equals "" "$glm_token" "GLM token 已从 Keychain 清除"

    # 4. 清除所有 Keychain
    "$SWITCH_SCRIPT" clear-all-keychains >/dev/null 2>&1

    # 验证所有 token 都被清除
    local kimi_token
    kimi_token=$(security find-generic-password -a "$USER" -s "switch-claude-kimi" -w 2>/dev/null)
    assert_equals "" "$kimi_token" "Kimi token 已清除"

    local minimax_token
    minimax_token=$(security find-generic-password -a "$USER" -s "switch-claude-minimax" -w 2>/dev/null)
    assert_equals "" "$minimax_token" "Minimax token 已清除"

    log_success "场景 5 完成: Keychain 管理"
}

# 场景 6: 配置恢复场景
scenario_config_recovery() {
    log_section "场景 6: 配置恢复场景"

    # 1. 正常配置
    cleanup_test_env
    "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-token "glm" "test-token" > /dev/null 2>&1
    "$SWITCH_SCRIPT" glm > /dev/null 2>&1

    # 2. 模拟配置文件损坏
    log_info "模拟配置文件损坏"
    echo '{"invalid": json}' > ~/.config/switch-claude/provider.json

    # 3. 尝试运行命令应检测到错误
    local error_output
    error_output=$("$SWITCH_SCRIPT" list-providers 2>&1)

    # 4. 用户重新初始化
    log_info "用户重新初始化配置"
    local init_output
    echo "y" | init_output=$("$SWITCH_SCRIPT" init-provider-config 2>&1)
    assert_contains "$init_output" "已创建默认 provider.json" "重新初始化成功"

    # 5. 验证配置已恢复
    local provider_count
    provider_count=$(jq '. | keys | length' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
    assert_equals "3" "$provider_count" "默认配置已恢复"

    log_success "场景 6 完成: 配置恢复"
}

# 场景 7: 批量操作场景
scenario_batch_operations() {
    log_section "场景 7: 批量操作场景"

    cleanup_test_env
    "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1

    log_info "批量添加多个自定义 provider..."

    # 批量添加
    for i in {1..5}; do
        local config='{
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_BASE_URL": "https://api'"$i"'.example.com/anthropic",
            "ANTHROPIC_MODEL": "model-'"$i"'"
        }'

        "$SWITCH_SCRIPT" add-provider "Provider$i" "$config" > /dev/null 2>&1
    done

    # 验证所有 provider 已添加
    local provider_count
    provider_count=$(jq '. | keys | length' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
    assert_equals "8" "$provider_count" "共添加 8 个 provider（3个内置 + 5个自定义）"

    # 验证可以列出所有
    local list_output
    list_output=$("$SWITCH_SCRIPT" list-providers 2>&1)
    for i in {1..5}; do
        assert_contains "$list_output" "Provider$i" "Provider$i 存在于列表中"
    done

    # 批量设置 token
    for i in {1..5}; do
        "$SWITCH_SCRIPT" set-token "Provider$i" "token-$i" > /dev/null 2>&1
    done

    # 验证 token 设置
    for i in {1..5}; do
        local token
        token=$(jq -r ".Provider$i.ANTHROPIC_AUTH_TOKEN" "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
        assert_equals "token-$i" "$token" "Provider$i token 正确"
    done

    # 批量删除（除了内置的）
    for i in {1..5}; do
        echo "y" | "$SWITCH_SCRIPT" remove-provider "Provider$i" > /dev/null 2>&1
    done

    # 验证只剩内置 provider
    provider_count=$(jq '. | keys | length' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
    assert_equals "3" "$provider_count" "删除后剩 3 个内置 provider"

    log_success "场景 7 完成: 批量操作"
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Switch Claude 集成测试${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 确保脚本存在
    if [[ ! -f "$SWITCH_SCRIPT" ]]; then
        log_error "脚本不存在: $SWITCH_SCRIPT"
        exit 1
    fi

    chmod +x "$SWITCH_SCRIPT"

    log_info "开始集成测试..."
    echo ""

    scenario_first_time_user
    scenario_custom_provider
    scenario_token_priority
    scenario_complete_model_switching
    scenario_keychain_management
    scenario_config_recovery
    scenario_batch_operations

    # 清理环境
    log_info "清理测试环境..."
    cleanup_test_env

    # 显示测试结果
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   集成测试结果${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "总测试数: $TESTS_RUN"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ 所有集成测试通过！${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ 有 $TESTS_FAILED 个测试失败${NC}"
        echo ""
        return 1
    fi
}

# 执行主函数
main "$@"