#!/usr/bin/env bash

# 快速测试脚本 - 用于开发环境，跳过可能卡住的检查
# 适合本地开发时快速验证

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== 快速开发测试 ===${NC}"
echo "项目根目录: $PROJECT_ROOT"
echo ""

# 测试计数器
TESTS_RUN=0
TESTS_PASSED=0

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
        return 1
    fi
    echo ""
}

# 基本文件检查
echo -e "${YELLOW}📁 基本文件检查${NC}"
run_test "脚本文件存在" "[[ -f '$PROJECT_ROOT/scripts/switch-claude.sh' ]]"
run_test "Formula文件存在" "[[ -f '$PROJECT_ROOT/Formula/switch-claude.rb' ]]"
run_test "脚本可执行" "[[ -x '$PROJECT_ROOT/scripts/switch-claude.sh' ]]"

# 语法检查
echo -e "${YELLOW}🔧 语法检查${NC}"
run_test "Bash语法检查" "bash -n '$PROJECT_ROOT/scripts/switch-claude.sh'"
run_test "Ruby语法检查" "ruby -c '$PROJECT_ROOT/Formula/switch-claude.rb' >/dev/null"

# 功能测试
echo -e "${YELLOW}🚀 功能测试${NC}"
run_test "帮助命令" "'$PROJECT_ROOT/scripts/switch-claude.sh' help >/dev/null"
run_test "当前配置命令" "'$PROJECT_ROOT/scripts/switch-claude.sh' current >/dev/null"
run_test "Token状态命令" "'$PROJECT_ROOT/scripts/switch-claude.sh' show-tokens >/dev/null"

# 项目结构检查
echo -e "${YELLOW}📋 项目结构检查${NC}"
for dir in scripts Formula docs tests; do
    run_test "$dir/ 目录存在" "[[ -d '$PROJECT_ROOT/$dir' ]]"
done

# 总结
echo -e "${BLUE}=== 测试完成 ===${NC}"
echo -e "通过测试: ${GREEN}$TESTS_PASSED${NC}/$TESTS_RUN"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}🎉 所有快速测试通过！${NC}"
    echo ""
    echo -e "${YELLOW}注意：${NC}"
    echo "- 这是开发环境的快速测试"
    echo "- 完整的CI测试会在GitHub Actions中运行"
    echo "- 包括brew audit、安装测试等完整检查"
    exit 0
else
    echo -e "${RED}❌ 有测试失败${NC}"
    exit 1
fi