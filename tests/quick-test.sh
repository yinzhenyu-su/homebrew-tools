#!/usr/bin/env bash

# 快速功能测试脚本
# 用于验证核心功能是否正常工作

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

assert_command_success() {
    local test_name="$1"
    shift

    TESTS_RUN=$((TESTS_RUN + 1))

    if "$@" > /dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

assert_command_failure() {
    local test_name="$1"
    shift

    TESTS_RUN=$((TESTS_RUN + 1))

    if "$@" > /dev/null 2>&1; then
        log_error "$test_name (应该失败但成功了)"
        return 1
    else
        log_success "$test_name"
        return 0
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
    security delete-generic-password -a "$USER" -s "switch-claude-glm" 2>/dev/null || true
    security delete-generic-password -a "$USER" -s "switch-claude-kimi" 2>/dev/null || true
    security delete-generic-password -a "$USER" -s "switch-claude-minimax" 2>/dev/null || true
    security delete-generic-password -a "$USER" -s "switch-claude-TestAPI" 2>/dev/null || true

    log_info "清理完成"
}

# 准备测试环境
setup_test_env() {
    log_info "准备测试环境..."

    # 确保脚本可执行
    chmod +x "$SWITCH_SCRIPT"

    # 创建必要的目录
    mkdir -p ~/.config/switch-claude

    # 初始清理
    cleanup_test_env

    log_info "测试环境准备完成"
}

# 测试 1: help 命令
test_help_command() {
    log_info "测试: help 命令"

    # 测试 help 输出
    if output=$("$SWITCH_SCRIPT" help 2>&1); then
        assert_equals "1" "$(echo "$output" | grep -c "用法")" "help 包含用法说明"
        assert_equals "1" "$(echo "$output" | grep -c "Provider 管理选项")" "help 包含 Provider 管理说明"
        assert_equals "1" "$(echo "$output" | grep -c "Token 管理选项")" "help 包含 Token 管理说明"
    else
        log_error "help 命令执行失败"
    fi
}

# 测试 2: 依赖检查
test_dependencies() {
    log_info "测试: 依赖检查"

    # 检查 jq
    if command -v jq > /dev/null 2>&1; then
        log_info "jq 已安装"
    else
        log_error "jq 未安装 - 请先安装: brew install jq"
    fi
}

# 测试 3: provider.json 自动创建
test_provider_auto_init() {
    log_info "测试: provider.json 自动创建"

    # 确保文件不存在
    cleanup_test_env

    # 首次运行 list-providers（应自动创建 provider.json）
    assert_command_success "自动创建 provider.json" "$SWITCH_SCRIPT" list-providers

    # 验证文件存在
    assert_file_exists "$HOME/.config/switch-claude/provider.json" "provider.json 已创建"

    # 验证包含三个默认 provider
    local provider_count=$(jq '. | keys | length' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
    assert_equals "3" "$provider_count" "包含 3 个默认 provider"
}

# 测试 4: list-providers 命令
test_list_providers() {
    log_info "测试: list-providers 命令"

    # 先确保有 provider.json
    if [[ ! -f "$HOME/.config/switch-claude/provider.json" ]]; then
        "$SWITCH_SCRIPT" list-providers > /dev/null 2>&1
    fi

    assert_command_success "list-providers 执行成功" "$SWITCH_SCRIPT" list-providers
}

# 测试 5: show-provider-config 命令
test_show_provider_config() {
    log_info "测试: show-provider-config 命令"

    assert_command_success "show-provider-config 执行成功" "$SWITCH_SCRIPT" show-provider-config
}

# 测试 6: add-provider 命令
test_add_provider() {
    log_info "测试: add-provider 命令"

    local test_config='{
        "ANTHROPIC_AUTH_TOKEN": "",
        "ANTHROPIC_BASE_URL": "https://api.test.com/anthropic",
        "ANTHROPIC_MODEL": "test-model"
    }'

    # 添加自定义 provider
    assert_command_success "添加自定义 provider" "$SWITCH_SCRIPT" add-provider "TestAPI" "$test_config"

    # 验证 provider 存在
    local exists=$(jq -e '.TestAPI' "$HOME/.config/switch-claude/provider.json" > /dev/null 2>&1 && echo "1" || echo "0")
    assert_equals "1" "$exists" "自定义 provider 已添加"
}

# 测试 7: set-token 命令
test_set_token() {
    log_info "测试: set-token 命令"

    # 设置 token
    assert_command_success "设置 token" "$SWITCH_SCRIPT" set-token "glm" "test-token-12345"

    # 验证 token 已设置
    local token=$(jq -r '.glm.ANTHROPIC_AUTH_TOKEN' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)
    assert_equals "test-token-12345" "$token" "Token 已保存到 provider.json"
}

# 测试 8: remove-provider 命令
test_remove_provider() {
    log_info "测试: remove-provider 命令"

    # 先确保有 TestAPI
    if [[ -z "$(jq -e '.TestAPI' "$HOME/.config/switch-claude/provider.json" 2>/dev/null)" ]]; then
        local test_config='{
            "ANTHROPIC_AUTH_TOKEN": "",
            "ANTHROPIC_BASE_URL": "https://api.test.com/anthropic",
            "ANTHROPIC_MODEL": "test-model"
        }'
        "$SWITCH_SCRIPT" add-provider "TestAPI" "$test_config" > /dev/null 2>&1
    fi

    # 使用 echo 模拟用户输入 'y'
    echo "y" | assert_command_success "删除自定义 provider" "$SWITCH_SCRIPT" remove-provider "TestAPI"

    # 验证 provider 不存在
    local exists=$(jq -e '.TestAPI' "$HOME/.config/switch-claude/provider.json" > /dev/null 2>&1 && echo "1" || echo "0")
    assert_equals "0" "$exists" "自定义 provider 已删除"
}

# 测试 9: 验证内置 provider 不可删除
test_cannot_remove_builtin_provider() {
    log_info "测试: 验证内置 provider 不可删除"

    assert_command_failure "不能删除内置 provider glm" "$SWITCH_SCRIPT" remove-provider "glm"
    assert_command_failure "不能删除内置 provider kimi" "$SWITCH_SCRIPT" remove-provider "kimi"
    assert_command_failure "不能删除内置 provider minimax" "$SWITCH_SCRIPT" remove-provider "minimax"
}

# 测试 10: set-keychain 命令
test_set_keychain() {
    log_info "测试: set-keychain 命令"

    assert_command_success "设置 keychain token" "$SWITCH_SCRIPT" set-keychain "kimi" "keychain-test-token"

    # 验证 keychain 中存在
    local keychain_token=$(security find-generic-password -a "$USER" -s "switch-claude-kimi" -w 2>/dev/null)
    assert_equals "keychain-test-token" "$keychain_token" "Token 已保存到 Keychain"
}

# 测试 11: clear-keychain 命令
test_clear_keychain() {
    log_info "测试: clear-keychain 命令"

    assert_command_success "清空 keychain token" "$SWITCH_SCRIPT" clear-keychain "kimi"

    # 验证 keychain 中不存在
    local keychain_token=$(security find-generic-password -a "$USER" -s "switch-claude-kimi" -w 2>/dev/null)
    if [[ -z "$keychain_token" ]]; then
        log_info "Keychain token 已清空"
    else
        log_warning "Keychain token 可能未完全清空"
    fi
}

# 测试 12: clear-all-keychains 命令
test_clear_all_keychains() {
    log_info "测试: clear-all-keychains 命令"

    # 先设置一些 tokens
    "$SWITCH_SCRIPT" set-keychain "glm" "token1" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "kimi" "token2" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "minimax" "token3" > /dev/null 2>&1

    assert_command_success "清空所有 keychain tokens" "$SWITCH_SCRIPT" clear-all-keychains
}

# 测试 13: 模型切换（不实际启动 Claude）
test_model_switching() {
    log_info "测试: 模型切换"

    # 为 provider 设置 token
    "$SWITCH_SCRIPT" set-keychain "glm" "glm-test-token" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "kimi" "kimi-test-token" > /dev/null 2>&1
    "$SWITCH_SCRIPT" set-keychain "minimax" "minimax-test-token" > /dev/null 2>&1

    # 切换到 GLM（不启动 Claude）
    assert_command_success "切换到 GLM" "$SWITCH_SCRIPT" glm

    # 切换到 Kimi
    assert_command_success "切换到 Kimi" "$SWITCH_SCRIPT" kimi

    # 切换到 Minimax
    assert_command_success "切换到 Minimax" "$SWITCH_SCRIPT" minimax
}

# 测试 14: current 命令
test_show_current() {
    log_info "测试: current 命令"

    assert_command_success "显示当前配置" "$SWITCH_SCRIPT" current
}

# 测试 15: 验证 provider 名称格式
test_invalid_provider_name() {
    log_info "测试: 无效 provider 名称验证"

    # 包含特殊字符
    assert_command_failure "拒绝包含特殊字符的名称" "$SWITCH_SCRIPT" add-provider "Invalid-Name!" '{}'

    # 超过 30 字符
    assert_command_failure "拒绝超过 30 字符的名称" "$SWITCH_SCRIPT" add-provider "Provider1234567890123456789012345" '{}'
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Switch Claude 快速功能测试${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 准备环境
    setup_test_env

    # 运行测试
    echo ""
    log_info "开始运行测试..."
    echo ""

    test_help_command
    test_dependencies
    test_provider_auto_init
    test_list_providers
    test_show_provider_config
    test_add_provider
    test_set_token
    test_remove_provider
    test_cannot_remove_builtin_provider
    test_set_keychain
    test_clear_keychain
    test_clear_all_keychains
    test_model_switching
    test_show_current
    test_invalid_provider_name

    # 清理环境
    echo ""
    log_info "清理测试环境..."
    cleanup_test_env

    # 显示测试结果
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   测试结果汇总${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "总测试数: $TESTS_RUN"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ 所有测试通过！${NC}"
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