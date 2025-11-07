#!/usr/bin/env bash

# 版本发布脚本
# 用于创建新版本并触发自动化发布流程

set -e

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
    if [[ -f "Formula/switch-claude.rb" ]]; then
        grep 'version' Formula/switch-claude.rb | sed -E 's/.*version[[:space:]]*"([^"]+)".*/\1/' | head -1
    else
        echo "0.0.0"
    fi
}

# 版本比较和递增
increment_version() {
    local version="$1"
    local type="$2"
    
    IFS='.' read -ra VERSION_PARTS <<< "$version"
    local major=${VERSION_PARTS[0]:-0}
    local minor=${VERSION_PARTS[1]:-0}
    local patch=${VERSION_PARTS[2]:-0}
    
    case "$type" in
        "major")
            echo "$((major + 1)).0.0"
            ;;
        "minor")
            echo "${major}.$((minor + 1)).0"
            ;;
        "patch")
            echo "${major}.${minor}.$((patch + 1))"
            ;;
        *)
            echo "$version"
            ;;
    esac
}

# 验证版本格式
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}错误: 版本格式无效 '$version'${NC}"
        echo "版本格式应为: x.y.z (例如: 1.0.0)"
        return 1
    fi
    return 0
}

# 检查工作区状态
check_workspace() {
    echo -e "${BLUE}检查工作区状态...${NC}"
    
    # 检查是否在git仓库中
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}错误: 不在Git仓库中${NC}"
        exit 1
    fi
    
    # 检查是否在main分支
    local current_branch=$(git branch --show-current)
    if [[ "$current_branch" != "main" ]]; then
        echo -e "${YELLOW}警告: 当前不在main分支 (当前: $current_branch)${NC}"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 检查工作区是否干净
    if ! git diff --quiet || ! git diff --staged --quiet; then
        echo -e "${RED}错误: 工作区有未提交的变更${NC}"
        echo "请先提交或储藏所有变更"
        git status --porcelain
        exit 1
    fi
    
    # 拉取最新代码
    echo "拉取最新代码..."
    git fetch origin
    git pull origin main
    
    echo -e "${GREEN}✅ 工作区检查通过${NC}"
}

# 更新版本信息
update_version_in_files() {
    local new_version="$1"
    
    echo -e "${BLUE}更新版本信息到 $new_version...${NC}"
    
    # 更新脚本中的版本注释
    if [[ -f "scripts/switch-claude.sh" ]]; then
        sed -i.bak "s/# Claude Code 模型切换脚本.*/# Claude Code 模型切换脚本 v${new_version}/" scripts/switch-claude.sh
        rm -f scripts/switch-claude.sh.bak
        echo "✅ 已更新 scripts/switch-claude.sh"
    fi
    
    # 更新README中的版本信息
    if [[ -f "README.md" ]]; then
        sed -i.bak "s/switch-claude [0-9]\+\.[0-9]\+\.[0-9]\+/switch-claude ${new_version}/g" README.md
        rm -f README.md.bak
        echo "✅ 已更新 README.md"
    fi
}

# 创建发布
create_release() {
    local new_version="$1"
    local current_version="$2"
    
    echo -e "${BLUE}准备发布版本 $new_version...${NC}"
    
    # 更新文件中的版本信息
    update_version_in_files "$new_version"
    
    # 生成变更日志
    echo -e "${BLUE}生成变更日志...${NC}"
    local changelog=""
    if [[ "$current_version" != "0.0.0" ]]; then
        local previous_tag="v$current_version"
        if git tag -l | grep -q "^$previous_tag$"; then
            changelog=$(git log --pretty=format:"- %s" "${previous_tag}..HEAD" | head -10)
        fi
    fi
    
    if [[ -z "$changelog" ]]; then
        changelog="- 初始版本发布"
    fi
    
    # 创建提交
    if ! git diff --quiet; then
        git add .
        git commit -m "chore: bump version to $new_version

$changelog

Prepare for release v$new_version"
        echo -e "${GREEN}✅ 已创建版本提交${NC}"
    fi
    
    # 创建标签
    local tag_name="v$new_version"
    echo -e "${BLUE}创建标签 $tag_name...${NC}"
    
    git tag -a "$tag_name" -m "Release version $new_version

$changelog"
    
    echo -e "${GREEN}✅ 已创建标签 $tag_name${NC}"
    
    # 推送到远程
    echo -e "${BLUE}推送到远程仓库...${NC}"
    git push origin main
    git push origin "$tag_name"
    
    echo -e "${GREEN}🎉 版本 $new_version 发布完成!${NC}"
    echo ""
    echo -e "${YELLOW}接下来会发生什么:${NC}"
    echo "1. GitHub Actions 会自动构建和发布"
    echo "2. Formula 会自动更新SHA256和URL"
    echo "3. 用户可以通过以下命令安装:"
    echo "   brew tap yinzhenyu-su/homebrew-tools"
    echo "   brew install switch-claude"
    echo ""
    echo -e "${BLUE}查看发布进度:${NC}"
    echo "https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
}

# 主函数
main() {
    local action="${1:-help}"
    
    case "$action" in
        "current")
            local current_version=$(get_current_version)
            echo -e "${BLUE}当前版本:${NC} $current_version"
            ;;
        "major"|"minor"|"patch")
            check_workspace
            local current_version=$(get_current_version)
            local new_version=$(increment_version "$current_version" "$action")
            
            echo -e "${BLUE}版本变更:${NC} $current_version -> $new_version"
            echo ""
            read -p "确认发布版本 $new_version? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                create_release "$new_version" "$current_version"
            else
                echo "发布已取消"
            fi
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            # 检查是否为版本号
            if validate_version "$action"; then
                check_workspace
                local current_version=$(get_current_version)
                
                echo -e "${BLUE}版本变更:${NC} $current_version -> $action"
                echo ""
                read -p "确认发布版本 $action? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    create_release "$action" "$current_version"
                else
                    echo "发布已取消"
                fi
            else
                echo -e "${RED}错误: 未知的操作 '$action'${NC}"
                echo ""
                show_help
                exit 1
            fi
            ;;
    esac
}

# 运行主函数
main "$@"