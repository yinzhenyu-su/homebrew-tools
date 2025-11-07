#!/usr/bin/env bash

# 版本发布脚本
# 用于创建新版本并触发自动化发布流程

set -euo pipefail
# 尝试启用 inherit_errexit（在较新 bash 中可使 set -e 在子 shell/替换中继承）
# 若不可用则忽略，不致脚本失败
shopt -s inherit_errexit 2>/dev/null || true

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}版本发布脚本${NC}

用法: ./scripts/release.sh [选项]

选项:
  major          发布主版本 (x.0.0)
  minor          发布次版本 (1.x.0)
  patch          发布补丁版本 (1.0.x)
  <version>      发布指定版本 (例如: 1.2.3)
  current        显示当前版本
  help           显示此帮助信息

示例:
  ./scripts/release.sh patch      # 1.0.0 -> 1.0.1
  ./scripts/release.sh minor      # 1.0.1 -> 1.1.0
  ./scripts/release.sh major      # 1.1.0 -> 2.0.0
  ./scripts/release.sh 1.5.0      # 发布指定版本
  ./scripts/release.sh current    # 显示当前版本

注意:
  - 脚本会自动检查工作区是否干净
  - 会自动创建Git标签并推送
  - 推送标签后会触发GitHub Actions自动发布流程
EOF
}

# 获取当前版本
get_current_version() {
    local version
    if [[ -f "Formula/switch-claude.rb" ]]; then
        version=$(grep 'version' Formula/switch-claude.rb | sed -E 's/.*version[[:space:]]*"([^\"]+)".*/\1/' | head -1) || true
    else
        version="0.0.0"
    fi

    printf '%s\n' "${version:-0.0.0}"
}

# 版本比较和递增
increment_version() {
    local version type
    version="$1"
    type="$2"

    IFS='.' read -ra VERSION_PARTS <<< "${version}"
    local major minor patch
    major=${VERSION_PARTS[0]:-0}
    minor=${VERSION_PARTS[1]:-0}
    patch=${VERSION_PARTS[2]:-0}

    case "${type}" in
        "major")
            printf '%s\n' "$((major + 1)).0.0"
            ;;
        "minor")
            printf '%s\n' "${major}.$((minor + 1)).0"
            ;;
        "patch")
            printf '%s\n' "${major}.${minor}.$((patch + 1))"
            ;;
        *)
            printf '%s\n' "${version}"
            return 0
            ;;
    esac
}

# 验证版本格式
validate_version() {
    local version
    version="$1"
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf '%b\n' "${RED}错误: 版本格式无效 '${version}'${NC}"
        printf '版本格式应为: x.y.z (例如: 1.0.0)\n'
        return 1
    fi
    return 0
}

# 检查工作区状态
check_workspace() {
    printf '%b\n' "${BLUE}检查工作区状态...${NC}"

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        printf '%b\n' "${RED}错误: 不在Git仓库中${NC}"
        exit 1
    fi

    local current_branch
    current_branch=$(git branch --show-current || true)
    if [[ "${current_branch}" != "main" ]]; then
        printf '%b\n' "${YELLOW}警告: 当前不在main分支 (当前: ${current_branch})${NC}"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! "${REPLY:-}" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    if ! git diff --quiet; then
        printf '%b\n' "${RED}错误: 工作区有未提交的变更${NC}"
        printf '请先提交或储藏所有变更\n'
        git status --porcelain
        exit 1
    fi
    if ! git diff --staged --quiet; then
        printf '%b\n' "${RED}错误: 暂存区有未提交的变更${NC}"
        git status --porcelain
        exit 1
    fi

    printf '拉取最新代码...\n'
    git fetch origin --quiet || true
    git pull origin main --ff-only || true

    printf '%b\n' "${GREEN}✅ 工作区检查通过${NC}"
}

# 更新版本信息
update_version_in_files() {
    local new_version
    new_version="$1"

    printf '%b\n' "${BLUE}更新版本信息到 ${new_version}...${NC}"

    if [[ -f "scripts/switch-claude.sh" ]]; then
        sed -E "s/^# (.*)/# \1 v${new_version}/" "scripts/switch-claude.sh" > "scripts/switch-claude.sh.tmp" || true
        mv "scripts/switch-claude.sh.tmp" "scripts/switch-claude.sh"
        printf '%b\n' "✅ 已更新 scripts/switch-claude.sh"
    fi

    if [[ -f "README.md" ]]; then
        sed -E "s/(switch-claude)[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+/\1 ${new_version}/g" README.md > README.md.tmp || true
        mv README.md.tmp README.md
        printf '%b\n' "✅ 已更新 README.md"
    fi
}

# 创建发布
create_release() {
    local new_version current_version changelog previous_tag
    new_version="$1"
    current_version="$2"

    printf '%b\n' "${BLUE}准备发布版本 ${new_version}...${NC}"

    update_version_in_files "${new_version}"

    printf '%b\n' "${BLUE}生成变更日志...${NC}"
    changelog=""
    if [[ "${current_version}" != "0.0.0" ]]; then
        previous_tag="v${current_version}"
        if git tag -l | grep -q "^${previous_tag}$"; then
            changelog=$(git log --pretty=format:"- %s" "${previous_tag}..HEAD" | head -10) || true
        fi
    fi

    if [[ -z "${changelog}" ]]; then
        changelog="- 初始版本发布"
    fi

    if ! git diff --quiet; then
        git add .
        git commit -m "chore: bump version to ${new_version}" -m "${changelog}" -m "Prepare for release v${new_version}"
        printf '%b\n' "${GREEN}✅ 已创建版本提交${NC}"
    else
        printf '未检测到变更，无需提交\n'
    fi

    local tag_name
    tag_name="v${new_version}"
    printf '%b\n' "${BLUE}创建标签 ${tag_name}...${NC}"
    git tag -a "${tag_name}" -m "Release version ${new_version}" -m "${changelog}" || true
    printf '%b\n' "${GREEN}✅ 已创建标签 ${tag_name}${NC}"

    printf '%b\n' "${BLUE}推送到远程仓库...${NC}"
    git push origin main --follow-tags || true
    git push origin "${tag_name}" || true

    printf '%b\n' "${GREEN}🎉 版本 ${new_version} 发布完成!${NC}"
    echo
    printf '%b\n' "${YELLOW}接下来会发生什么:${NC}"
    echo "1. GitHub Actions 会自动构建和发布"
    echo "2. Formula 会自动更新SHA256和URL"
    echo "3. 用户可以通过以下命令安装:"
    echo "   brew tap yinzhenyu-su/homebrew-tools"
    echo "   brew install switch-claude"
    echo
    printf '%b\n' "${BLUE}查看发布进度:${NC}"
    local origin_url repo_path
    origin_url=$(git config --get remote.origin.url || true)
    repo_path=$(printf '%s' "${origin_url}" | sed -E 's/.*github.com[:/](.+?)(\.git)?$/\1/' || true)
    echo "https://github.com/${repo_path}/actions"
}

# 主函数
main() {
    local action
    action="${1:-help}"

    case "${action}" in
        "current")
            local current_version
            current_version=$(get_current_version)
            printf '%b\n' "${BLUE}当前版本:${NC} ${current_version}"
            ;;
        "major"|"minor"|"patch")
            check_workspace
            local current_version new_version
            current_version=$(get_current_version)
            new_version=$(increment_version "${current_version}" "${action}")
            printf '%b\n' "${BLUE}版本变更:${NC} ${current_version} -> ${new_version}"
            echo
            read -p "确认发布版本 ${new_version}? (y/N): " -n 1 -r
            echo
            if [[ "${REPLY:-}" =~ ^[Yy]$ ]]; then
                create_release "${new_version}" "${current_version}"
            else
                echo "发布已取消"
            fi
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            if validate_version "${action}"; then
                check_workspace
                local current_version
                current_version=$(get_current_version)
                printf '%b\n' "${BLUE}版本变更:${NC} ${current_version} -> ${action}"
                echo
                read -p "确认发布版本 ${action}? (y/N): " -n 1 -r
                echo
                if [[ "${REPLY:-}" =~ ^[Yy]$ ]]; then
                    create_release "${action}" "${current_version}"
                else
                    echo "发布已取消"
                fi
            else
                printf '%b\n' "${RED}错误: 未知的操作 '${action}'${NC}"
                echo
                show_help
                exit 1
            fi
            ;;
    esac
}

# 运行主函数
main "$@"