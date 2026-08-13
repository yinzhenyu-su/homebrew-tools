#!/usr/bin/env bash
# adb-qr-pair 错误处理测试：验证缺失依赖场景的报错与退出码
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../../scripts/adb-qr-pair.sh"

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_error()   { echo -e "${RED}[✗]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# 受限环境运行脚本, 断言退出码非 0 且输出含指定片段
# 注意: 脚本 shebang 是 #!/usr/bin/env sh, 受限 PATH 下 env 找不到 sh,
# 所以统一用 /bin/sh "$TARGET_SCRIPT" 显式执行; 这些错误分支只用 sh 内置命令,
# 不依赖 PATH 中的外部命令, 受限 PATH 下依然可测。
# $1=测试名  $2=期望错误片段  $3=PATH  $4=ADB
run_error_case() {
    local name="$1" expected="$2" test_path="$3" adb_path="$4"
    TESTS_RUN=$((TESTS_RUN + 1))
    local output exit_code=0
    output=$(PATH="$test_path" ADB="$adb_path" /bin/sh "$TARGET_SCRIPT" 2>&1) || exit_code=$?
    if [[ $exit_code -ne 0 ]] && grep -qF "$expected" <<< "$output"; then
        log_success "$name (exit=$exit_code)"
    else
        log_error "$name"
        echo "  期望错误片段: $expected"
        echo "  实际退出码: ${exit_code:-0}"
        echo "  实际输出:"
        echo "$output" | sed 's/^/    /'
    fi
}

# 用例 A: POSIX sh 语法检查
test_syntax() {
    log_info "测试: POSIX sh 语法"
    TESTS_RUN=$((TESTS_RUN + 1))
    if /bin/sh -n "$TARGET_SCRIPT" 2>/dev/null; then log_success "sh -n 通过"; else log_error "sh -n 失败"; fi
}

# 用例 B: adb 缺失 (ADB 指向不存在路径, 且受限 PATH 无 adb 可回退)
test_missing_adb() {
    log_info "测试: 找不到 adb"
    run_error_case "ADB 指向不存在路径时报错退出" "找不到 adb" "/nonexistent" "/nonexistent/adb"
}

# 用例 C: timeout 与 perl 均不可用
test_missing_timeout_or_perl() {
    log_info "测试: 未找到 timeout 或 perl"
    local fake_bin
    fake_bin=$(mktemp -d)
    printf '#!/bin/sh\nexit 0\n' > "$fake_bin/adb"
    chmod +x "$fake_bin/adb"
    run_error_case "缺 timeout/perl 时报错退出" "未找到 timeout 或 perl" "$fake_bin" "$fake_bin/adb"
    rm -rf "$fake_bin"
}

# 用例 D: mDNS 发现工具缺失 (有 adb + timeout, 无 dns-sd / avahi-browse)
test_missing_mdns() {
    log_info "测试: 未找到 mDNS 发现工具"
    local fake_bin
    fake_bin=$(mktemp -d)
    printf '#!/bin/sh\nexit 0\n' > "$fake_bin/adb"
    printf '#!/bin/sh\nexit 0\n' > "$fake_bin/timeout"
    chmod +x "$fake_bin/adb" "$fake_bin/timeout"
    run_error_case "缺 mDNS 工具时报错退出" "未找到 mDNS 发现工具" "$fake_bin" "$fake_bin/adb"
    rm -rf "$fake_bin"
}

# 用例 E: 脚本可执行位 (Formula bin.install 与 ./scripts 直跑都依赖)
test_executable_bit() {
    log_info "测试: 脚本可执行位"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -x "$TARGET_SCRIPT" ]]; then log_success "脚本可执行"; else log_error "缺少可执行位 (chmod +x scripts/adb-qr-pair.sh)"; fi
}

main() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   ADB QR Pair 错误处理测试${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    test_syntax
    test_executable_bit
    test_missing_adb
    test_missing_timeout_or_perl
    test_missing_mdns
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   错误处理测试结果${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "总测试数: $TESTS_RUN"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    echo ""
    [[ $TESTS_FAILED -eq 0 ]] && echo -e "${GREEN}✓ 所有错误处理测试通过！${NC}" || echo -e "${YELLOW}⚠ 存在失败用例${NC}"
    return 0
}
main "$@"
