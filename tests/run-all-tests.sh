#!/usr/bin/env bash

# 运行所有测试套件
# 自动发现 tests/*/ 子目录中的测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 自动发现测试套件：从 tests/*/ 子目录中收集所有 .sh 测试脚本
declare -a TEST_SUITES=()     # 描述
declare -a TEST_SCRIPTS=()    # 脚本路径

discover_test_suites() {
    TEST_SUITES=()
    TEST_SCRIPTS=()

    for tool_dir in "$SCRIPT_DIR"/*/; do
        [[ -d "$tool_dir" ]] || continue
        local tool_name
        tool_name=$(basename "$tool_dir")

        for script in "$tool_dir"/*.sh; do
            [[ -f "$script" ]] || continue
            local script_name
            script_name=$(basename "$script" .sh)
            TEST_SUITES+=("${tool_name}: ${script_name}")
            TEST_SCRIPTS+=("$script")
        done
    done
}

# 全局测试计数器
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TESTSuites=0

# 解析测试结果
parse_test_results() {
    local output_file="$1"

    # 去除颜色码并提取测试统计信息
    local clean_output=$(sed 's/\x1b\[[0-9;]*m//g' "$output_file")

    # 查找测试统计信息
    local test_count=$(echo "$clean_output" | grep -E "^总测试数:" | tail -1 | sed 's/^总测试数: *//' | tr -d ' ')
    local passed_count=$(echo "$clean_output" | grep -E "^通过:" | tail -1 | sed 's/^通过: *//' | tr -d ' ')
    local failed_count=$(echo "$clean_output" | grep -E "^失败:" | tail -1 | sed 's/^失败: *//' | tr -d ' ')

    # 累加到全局计数器
    if [[ -n "$test_count" && "$test_count" =~ ^[0-9]+$ ]]; then
        TOTAL_TESTS=$((TOTAL_TESTS + test_count))
    fi
    if [[ -n "$passed_count" && "$passed_count" =~ ^[0-9]+$ ]]; then
        TOTAL_PASSED=$((TOTAL_PASSED + passed_count))
    fi
    if [[ -n "$failed_count" && "$failed_count" =~ ^[0-9]+$ ]]; then
        TOTAL_FAILED=$((TOTAL_FAILED + failed_count))
    fi
}

# 显示横幅
show_banner() {
    # CI 环境无 TERM 时 clear 会报错, 需容错避免触发 set -e
    clear 2>/dev/null || true
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║          Homebrew Tools 测试套件                             ║"
    echo "║                                                              ║"
    echo "║  1. 运行所有测试 (推荐)                                       ║"
    echo "║  2. 选择测试套件                                             ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}选择测试模式:${NC}"
    echo ""
}

# 运行测试套件
run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    local description="$3"

    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  正在运行: $test_name${NC}"
    echo -e "${MAGENTA}  描述: $description${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ ! -f "$test_script" ]]; then
        echo -e "${RED}错误: 测试脚本不存在: $test_script${NC}"
        return 1
    fi

    chmod +x "$test_script"

    # 创建临时文件存储测试输出
    local test_output=$(mktemp)

    local start_time=$(date +%s)
    if bash "$test_script" > "$test_output" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        echo -e "${GREEN}✓ $test_name 完成 (耗时: ${duration}秒)${NC}"
        TESTSuites=$((TESTSuites + 1))
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        echo -e "${YELLOW}⚠ $test_name 完成，但有部分测试失败 (耗时: ${duration}秒)${NC}"
        TESTSuites=$((TESTSuites + 1))
    fi

    # 解析测试统计信息
    parse_test_results "$test_output"
    rm -f "$test_output"

    return 0
}

# 生成测试报告
generate_report() {
    local report_file="$SCRIPT_DIR/test-report.html"

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Homebrew Tools 测试报告</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .content {
            padding: 40px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .summary-card {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            transition: transform 0.3s;
        }
        .summary-card:hover {
            transform: translateY(-5px);
        }
        .summary-card h3 {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 10px;
            text-transform: uppercase;
        }
        .summary-card .number {
            font-size: 3em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .summary-card.passed .number {
            color: #28a745;
        }
        .summary-card.failed .number {
            color: #dc3545;
        }
        .summary-card.total .number {
            color: #007bff;
        }
        .summary-card.suites .number {
            color: #6f42c1;
        }
        .chart-container {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 30px;
        }
        .progress-bar {
            background: #e9ecef;
            border-radius: 10px;
            height: 40px;
            overflow: hidden;
            margin-top: 20px;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745, #20c997);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            transition: width 1s ease;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px 40px;
            text-align: center;
            color: #666;
            border-top: 1px solid #dee2e6;
        }
        .timestamp {
            color: #999;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 测试报告</h1>
            <p>Homebrew Tools 测试详细结果</p>
        </div>
        <div class="content">
            <div class="summary">
                <div class="summary-card total">
                    <h3>总测试数</h3>
                    <div class="number">TOTAL_TESTS_VAR</div>
                </div>
                <div class="summary-card passed">
                    <h3>通过</h3>
                    <div class="number">PASSED_TESTS_VAR</div>
                </div>
                <div class="summary-card failed">
                    <h3>失败</h3>
                    <div class="number">FAILED_TESTS_VAR</div>
                </div>
                <div class="summary-card suites">
                    <h3>测试套件</h3>
                    <div class="number">SUITES_VAR</div>
                </div>
            </div>

            <div class="chart-container">
                <h2 style="margin-bottom: 20px;">测试通过率</h2>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: PASS_PERCENT_VAR%">
                        PASS_PERCENT_VAR%
                    </div>
                </div>
            </div>
        </div>
        <div class="footer">
            <p>测试报告生成时间: <span class="timestamp">TIMESTAMP_VAR</span></p>
            <p style="margin-top: 10px;">Homebrew Tools</p>
        </div>
    </div>
    <script>
        window.addEventListener('load', function() {
            const progressFill = document.querySelector('.progress-fill');
            const width = progressFill.style.width;
            progressFill.style.width = '0%';
            setTimeout(() => {
                progressFill.style.width = width;
            }, 100);
        });
    </script>
</body>
</html>
EOF

    # 替换变量
    local pass_percent=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_percent=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|TOTAL_TESTS_VAR|$TOTAL_TESTS|g" "$report_file"
        sed -i '' "s|PASSED_TESTS_VAR|$TOTAL_PASSED|g" "$report_file"
        sed -i '' "s|FAILED_TESTS_VAR|$TOTAL_FAILED|g" "$report_file"
        sed -i '' "s|SUITES_VAR|$TESTSuites|g" "$report_file"
        sed -i '' "s|PASS_PERCENT_VAR|$pass_percent|g" "$report_file"
        sed -i '' "s|TIMESTAMP_VAR|$timestamp|g" "$report_file"
    else
        sed -i "s|TOTAL_TESTS_VAR|$TOTAL_TESTS|g" "$report_file"
        sed -i "s|PASSED_TESTS_VAR|$TOTAL_PASSED|g" "$report_file"
        sed -i "s|FAILED_TESTS_VAR|$TOTAL_FAILED|g" "$report_file"
        sed -i "s|SUITES_VAR|$TESTSuites|g" "$report_file"
        sed -i "s|PASS_PERCENT_VAR|$pass_percent|g" "$report_file"
        sed -i "s|TIMESTAMP_VAR|$timestamp|g" "$report_file"
    fi

    echo -e "${GREEN}✓ 测试报告已生成: $report_file${NC}"
}

# 主函数
main() {
    discover_test_suites

    show_banner

    local total_suites=${#TEST_SUITES[@]}

    if [[ $total_suites -eq 0 ]]; then
        echo -e "${RED}错误: 未找到测试套件${NC}"
        echo "请确保 tests/ 目录下有子目录包含 .sh 测试脚本"
        exit 1
    fi

    echo ""
    # 非交互/CI 环境（stdin 非终端或设置了 CI=true）跳过菜单直接运行全部测试。
    # read 在 stdin EOF 时返回非零，需 `|| true` 避免触发 set -e（此前 CI 模式从未真正生效）
    if [[ -n "${CI:-}" ]] || [[ ! -t 0 ]]; then
        choice="1"
    else
        read -p "请选择 [1-2]: " choice || true
    fi

    case "$choice" in
        1)
            echo -e "\n${GREEN}运行所有测试...${NC}\n"
            for i in "${!TEST_SCRIPTS[@]}"; do
                run_test_suite "${TEST_SUITES[$i]}" "${TEST_SCRIPTS[$i]}" ""
            done
            ;;
        2)
            echo ""
            for i in "${!TEST_SUITES[@]}"; do
                echo -e "  $((i+1))). ${TEST_SUITES[$i]}"
            done
            echo ""
            read -p "请选择 [1-$total_suites]: " suite_choice || true

            if [[ "$suite_choice" =~ ^[0-9]+$ ]] && (( suite_choice >= 1 && suite_choice <= total_suites )); then
                local idx=$((suite_choice - 1))
                run_test_suite "${TEST_SUITES[$idx]}" "${TEST_SCRIPTS[$idx]}" ""
            else
                echo -e "${RED}无效选择${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${YELLOW}运行所有测试...${NC}\n"
            for i in "${!TEST_SCRIPTS[@]}"; do
                run_test_suite "${TEST_SUITES[$i]}" "${TEST_SCRIPTS[$i]}" ""
            done
            ;;
    esac

    # 显示最终结果
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}     所有测试完成${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  总测试套件: ${TESTSuites}"
    echo -e "  总测试数: $TOTAL_TESTS"
    echo -e "  ${GREEN}通过: $TOTAL_PASSED${NC}"
    echo -e "  ${RED}失败: $TOTAL_FAILED${NC}"
    echo ""

    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local pass_percent=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
        echo -e "  通过率: ${pass_percent}%"
        echo ""
    fi

    # 生成报告
    generate_report

    # 提供进一步操作
    echo ""
    echo -e "${BLUE}进一步操作:${NC}"
    echo "  - 查看 HTML 报告: open $SCRIPT_DIR/test-report.html"
    echo "  - 重新运行: $0"
    echo ""

    # 返回适当的退出码
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# 捕获 Ctrl+C 并优雅退出
trap 'echo -e "\n${YELLOW}测试被用户中断${NC}"; exit 130' INT

# 执行主函数
main "$@"
