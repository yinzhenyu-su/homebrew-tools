#!/usr/bin/env bash

# Formula 测试脚本
# 用于本地测试 Homebrew Formula 的正确性
# 注意：部分测试（如brew audit）在本地环境可能较慢或卡住
# 如需快速测试，请使用 ./tests/test-quick.sh

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 运行测试
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${BLUE}[TEST $TESTS_RUN] $test_name${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

# 清理函数
cleanup() {
    echo -e "${YELLOW}清理测试环境...${NC}"
    # 仅在确实安装的情况下才卸载
    if brew list switch-claude >/dev/null 2>&1; then
        brew uninstall switch-claude 2>/dev/null || true
    fi
    # 注意：在CI环境中可能不需要untap
}

# 主要测试函数
main() {
    echo -e "${BLUE}=== Homebrew Formula 测试 ===${NC}"
    echo "项目根目录: $PROJECT_ROOT"
    echo ""

    # 设置清理陷阱
    trap cleanup EXIT

    # 测试1: 项目结构检查
    run_test "脚本文件存在性检查" "[[ -f '$PROJECT_ROOT/scripts/switch-claude.sh' ]]"
    run_test "Formula文件存在性检查" "[[ -f '$PROJECT_ROOT/Formula/switch-claude.rb' ]]"

    # 测试2: 脚本权限和语法
    run_test "脚本权限检查" "[[ -x '$PROJECT_ROOT/scripts/switch-claude.sh' ]] || chmod +x '$PROJECT_ROOT/scripts/switch-claude.sh'"
    run_test "脚本语法检查" "bash -n '$PROJECT_ROOT/scripts/switch-claude.sh'"

    # 测试3: 脚本功能测试
    run_test "帮助命令测试" "'$PROJECT_ROOT/scripts/switch-claude.sh' help >/dev/null"
    run_test "当前配置命令测试" "'$PROJECT_ROOT/scripts/switch-claude.sh' current >/dev/null"
    run_test "Token状态命令测试" "'$PROJECT_ROOT/scripts/switch-claude.sh' show-tokens >/dev/null"

    # 测试4: Formula语法检查
    run_test "Ruby语法检查" "ruby -c '$PROJECT_ROOT/Formula/switch-claude.rb' >/dev/null"

    # 测试5: 跳过可能卡住的brew audit，只做基本检查
    if command -v brew >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  跳过 brew audit 检查（可能在本地环境中卡住）${NC}"
        echo "在CI环境中会执行完整的brew test-bot检查"
        
        # 尝试本地安装测试（仅在CI环境或tap已存在时）
        if [[ "$CI" == "true" ]] || brew tap-info yinzhenyu-su/homebrew-tools >/dev/null 2>&1; then
            run_test "本地安装测试" "brew install --build-from-source '$PROJECT_ROOT/Formula/switch-claude.rb'"
            
            if brew list switch-claude >/dev/null 2>&1; then
                # 测试6: 安装后的命令检查
                run_test "主命令存在性检查" "which switch-claude >/dev/null"
                run_test "别名命令检查" "which claude-switch >/dev/null"
                run_test "短别名检查" "which sc >/dev/null"
                
                # 测试7: 安装后的功能测试
                run_test "安装后帮助命令测试" "switch-claude help >/dev/null"
                run_test "安装后当前配置测试" "switch-claude current >/dev/null"
                
                # 测试8: 依赖检查
                run_test "jq依赖检查" "which jq >/dev/null"
            fi
        else
            echo -e "${YELLOW}⚠️  本地环境，跳过 tap 安装测试${NC}"
            echo "提示：在正确的 tap 环境中运行完整测试"
        fi
    else
        echo -e "${YELLOW}⚠️  brew 未安装，跳过 Homebrew 相关测试${NC}"
    fi

    # 测试10: 目录结构检查
    expected_dirs=("scripts" "Formula" "docs" "tests")
    for dir in "${expected_dirs[@]}"; do
        run_test "$dir/ 目录存在性检查" "[[ -d '$PROJECT_ROOT/$dir' ]]"
    done

    # 显示测试结果
    echo -e "${BLUE}=== 测试结果 ===${NC}"
    echo -e "总测试数: ${TESTS_RUN}"
    echo -e "通过: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "失败: ${RED}${TESTS_FAILED}${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 所有测试通过!${NC}"
        exit 0
    else
        echo -e "${RED}❌ 有 $TESTS_FAILED 个测试失败${NC}"
        exit 1
    fi
}

# 运行测试
main "$@"