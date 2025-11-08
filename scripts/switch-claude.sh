#!/usr/bin/env bash

# Claude Code 模型切换脚本
# 支持 Kimi、GLM、Minimax 三个模型之间的切换
# 通过修改 ~/.claude/settings.json 文件实现
# 
# Homebrew Formula: yinzhenyu-su/homebrew-tools/switch-claude
# 安装方式: brew tap yinzhenyu-su/tools && brew install switch-claude

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="$HOME/.claude/settings.json"
CONFIG_DIR="$HOME/.config/switch-claude"
TOKENS_FILE="$CONFIG_DIR/tokens.json"
PROVIDER_CONFIG_FILE="$CONFIG_DIR/provider.json"

# ========== 平台检测模块 ==========
# 用于跨平台功能检测和动态加载

# 平台检测变量
OS_TYPE=""
HAS_JQ=false
HAS_KEYCHAIN=false
HAS_SECRET_TOOL=false
HAS_GUM=false

# 检测操作系统和可用工具
init_platform() {
    # 检测操作系统
    case "$OSTYPE" in
        darwin*)    OS_TYPE="macos" ;;
        linux*)     OS_TYPE="linux" ;;
        *)          OS_TYPE="unknown" ;;
    esac

    # 检测工具可用性
    command -v jq >/dev/null 2>&1 && HAS_JQ=true

    if [[ "$OS_TYPE" == "macos" ]]; then
        command -v security >/dev/null 2>&1 && HAS_KEYCHAIN=true
    fi

    if [[ "$OS_TYPE" == "linux" ]]; then
        command -v secret-tool >/dev/null 2>&1 && HAS_SECRET_TOOL=true
    fi

    command -v gum >/dev/null 2>&1 && HAS_GUM=true
}

# 初始化平台检测
init_platform

# ========== 公共函数 ==========

# 清理 token 中的换行符和回车符
clean_token() {
    local token="$1"
    # 删除所有换行符和回车符，以及首尾空格
    # 使用原生 bash 操作避免 subshell 问题
    token="${token//[$'\r\n']/}"  # 删除所有换行符和回车符
    token="${token#"${token%%[![:space:]]*}"}"  # 删除前缀空格
    token="${token%"${token##*[![:space:]]}"}"  # 删除后缀空格
    echo "$token"
}

# 验证 provider 是否有效（内置或自定义）
validate_provider() {
    local provider="$1"

    # 首先检查内置 provider
    case "$provider" in
        "glm"|"kimi"|"minimax") return 0 ;;
    esac

    # 然后检查自定义 provider
    if [[ -f "$PROVIDER_CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
        if jq -e ".$provider" "$PROVIDER_CONFIG_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

# ========== 配置检查和验证函数 ==========

# 检查和验证 provider.json
check_provider_config() {
    # 如果文件不存在，自动创建
    if [[ ! -f "$PROVIDER_CONFIG_FILE" ]]; then
        echo -e "${YELLOW}检测到缺少 provider.json，正在自动初始化...${NC}"
        echo ""
        init_provider_config "true"  # 强制创建，不提示确认
        return 0
    fi

    # 文件存在，检查格式
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}错误: 需要安装 jq 来验证配置文件${NC}"
        return 1
    fi

    # 验证 JSON 格式
    local jq_result
    jq_result=$(jq empty "$PROVIDER_CONFIG_FILE" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}错误: provider.json 格式不正确${NC}"
        echo ""
        # 显示 jq 的错误信息（如果有）
        if [[ -n "$jq_result" ]]; then
            echo "错误详情: $jq_result"
            echo ""
        fi
        echo "请检查文件: $PROVIDER_CONFIG_FILE"
        echo ""
        echo "可能的错误:"
        echo "  - JSON 语法错误（缺少逗号、引号、花括号等）"
        echo "  - 文件被意外修改"
        echo ""
        echo "解决方案:"
        echo "  1. 运行: switch-claude init-provider-config 重新创建"
        echo "  2. 或手动检查并修复 JSON 格式"
        echo ""
        return 1
    fi

    # 检查至少有一个 provider
    local provider_count
    provider_count=$(jq '. | keys | length' "$PROVIDER_CONFIG_FILE" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$provider_count" ]] || [[ "$provider_count" -eq 0 ]]; then
        echo -e "${RED}错误: provider.json 中没有配置任何 provider${NC}"
        echo ""
        echo "请检查文件: $PROVIDER_CONFIG_FILE"
        echo ""
        echo "解决方案:"
        echo "  1. 运行: switch-claude init-provider-config 重新创建"
        echo "  2. 或使用: switch-claude add-provider 添加 provider"
        echo ""
        return 1
    fi

    return 0
}

# ========== Provider 配置管理函数 ==========

# 验证 provider 名称格式
validate_provider_name() {
    local name="$1"

    # 检查是否为空
    if [[ -z "$name" ]]; then
        echo -e "${RED}错误: provider 名称不能为空${NC}"
        return 1
    fi

    # 检查长度（建议 1-30 字符）
    if [[ ${#name} -gt 30 ]]; then
        echo -e "${RED}错误: provider 名称不能超过 30 个字符${NC}"
        return 1
    fi

    # 验证格式：英文大小写字母和数字
    if ! [[ "$name" =~ ^[a-zA-Z0-9]+$ ]]; then
        echo -e "${RED}错误: provider 名称只能包含英文字母和数字${NC}"
        echo "示例: MyProvider123, customAPI, provider2024"
        return 1
    fi

    # 检查是否与内置 provider 冲突
    case "$name" in
        "glm"|"kimi"|"minimax")
            echo -e "${YELLOW}警告: '$name' 是内置 provider，建议使用其他名称${NC}"
            read -p "确定要继续吗？(y/n): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                return 1
            fi
            ;;
    esac

    return 0
}

# 验证环境变量配置 JSON
validate_env_config() {
    local env_config="$1"

    # 检查是否为空
    if [[ -z "$env_config" ]]; then
        echo -e "${RED}错误: 环境变量配置不能为空${NC}"
        return 1
    fi

    # 使用 jq 验证 JSON 格式
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        echo "$env_config" > "$temp_file"

        if ! jq empty "$temp_file" 2>/dev/null; then
            echo -e "${RED}错误: 环境变量配置不是有效的 JSON 格式${NC}"
            echo ""
            echo "示例格式:"
            echo '{'
            echo '  "ANTHROPIC_AUTH_TOKEN": "",'
            echo '  "ANTHROPIC_BASE_URL": "https://api.custom.com/anthropic",'
            echo '  "ANTHROPIC_MODEL": "custom-model"'
            echo '}'
            rm -f "$temp_file"
            return 1
        fi

        # 检查必需字段
        local base_url=$(jq -r '.ANTHROPIC_BASE_URL // empty' "$temp_file")
        if [[ -z "$base_url" ]]; then
            echo -e "${RED}错误: 必须包含 ANTHROPIC_BASE_URL 字段${NC}"
            rm -f "$temp_file"
            return 1
        fi

        # 检查至少一个模型字段
        local has_model=false
        for field in "ANTHROPIC_MODEL" "ANTHROPIC_DEFAULT_HAIKU_MODEL" \
                     "ANTHROPIC_DEFAULT_SONNET_MODEL" "ANTHROPIC_DEFAULT_OPUS_MODEL" \
                     "ANTHROPIC_SMALL_FAST_MODEL"; do
            if jq -e ".$field" "$temp_file" >/dev/null 2>&1; then
                has_model=true
                break
            fi
        done

        if [[ "$has_model" != "true" ]]; then
            echo -e "${RED}错误: 至少需要配置一个模型字段${NC}"
            echo "可选的模型字段:"
            echo "  - ANTHROPIC_MODEL"
            echo "  - ANTHROPIC_DEFAULT_HAIKU_MODEL"
            echo "  - ANTHROPIC_DEFAULT_SONNET_MODEL"
            echo "  - ANTHROPIC_DEFAULT_OPUS_MODEL"
            echo "  - ANTHROPIC_SMALL_FAST_MODEL"
            rm -f "$temp_file"
            return 1
        fi

        rm -f "$temp_file"
        return 0
    else
        echo -e "${RED}错误: 需要安装 jq 来验证 JSON${NC}"
        return 1
    fi
}

# 读取 provider 配置
read_provider_config() {
    local provider="$1"

    if [[ ! -f "$PROVIDER_CONFIG_FILE" ]]; then
        echo -e "${RED}错误: provider 配置文件不存在: $PROVIDER_CONFIG_FILE${NC}" >&2
        echo "" >&2
        echo "请使用以下命令创建默认配置:" >&2
        echo "  switch-claude init-provider-config" >&2
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        jq -c ".$provider" "$PROVIDER_CONFIG_FILE" 2>/dev/null
    else
        echo -e "${RED}错误: 需要安装 jq 来处理 JSON 配置文件${NC}" >&2
        return 1
    fi
}

# 创建默认 provider.json
init_provider_config() {
    local force="${1:-false}"  # 是否强制重新创建（跳过确认）

    ensure_token_dir

    if [[ -f "$PROVIDER_CONFIG_FILE" && "$force" != "true" ]]; then
        echo -e "${YELLOW}provider.json 已存在${NC}"
        read -p "是否要重新创建？(会覆盖现有配置) (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "已取消"
            return 0
        fi
    fi

    cat > "$PROVIDER_CONFIG_FILE" << 'EOF'
{
  "glm": {
    "ANTHROPIC_AUTH_TOKEN": "",
    "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.6"
  },
  "kimi": {
    "ANTHROPIC_AUTH_TOKEN": "",
    "ANTHROPIC_BASE_URL": "https://api.moonshot.cn/anthropic",
    "ANTHROPIC_MODEL": "kimi-k2-turbo-preview",
    "ANTHROPIC_SMALL_FAST_MODEL": "kimi-k2-turbo-preview"
  },
  "minimax": {
    "ANTHROPIC_AUTH_TOKEN": "",
    "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_MODEL": "MiniMax-M2",
    "ANTHROPIC_SMALL_FAST_MODEL": "MiniMax-M2",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2"
  }
}
EOF

    echo -e "${GREEN}已创建默认 provider.json: $PROVIDER_CONFIG_FILE${NC}"
}

# 显示 provider 配置
show_provider_config() {
    if [[ ! -f "$PROVIDER_CONFIG_FILE" ]]; then
        echo -e "${YELLOW}provider.json 不存在${NC}"
        echo "请使用以下命令创建:"
        echo "  switch-claude init-provider-config"
        return 0
    fi

    if command -v jq >/dev/null 2>&1; then
        echo -e "${BLUE}Provider 配置:${NC}"
        echo ""

        # 脱敏显示所有 provider
        jq -r '
            to_entries[] |
            "[\(.key)]" +
            (.value | to_entries | map(select(.key == "ANTHROPIC_AUTH_TOKEN") | .value) |
                if .[0] != "" then
                    " Token: " + .[0][0:10] + "..." + .[0][-4:]
                else
                    " Token: (未设置)"
                end
            ) +
            "\n  Base URL: " + (.value.ANTHROPIC_BASE_URL // "未设置")
        ' "$PROVIDER_CONFIG_FILE" 2>/dev/null

        echo ""
        echo -e "${YELLOW}可用的模型字段:${NC}"
        jq -r '
            to_entries[0].value |
            to_entries |
            map(select(.key | startswith("ANTHROPIC") and contains("MODEL"))) |
            map("  - " + .key) |
            .[]
        ' "$PROVIDER_CONFIG_FILE" 2>/dev/null
    else
        echo -e "${YELLOW}请安装 jq 以获得更好的显示效果${NC}"
        echo "文件位置: $PROVIDER_CONFIG_FILE"
    fi
}

# 添加新的 provider
add_provider() {
    if [[ $# -ne 2 ]]; then
        echo -e "${RED}错误: add-provider 需要 2 个参数${NC}"
        echo "用法: switch-claude add-provider <provider_name> <env_config_json>"
        return 1
    fi

    local provider_name="$1"
    local env_config_json="$2"

    # 1. 验证 provider 名称
    if ! validate_provider_name "$provider_name"; then
        return 1
    fi

    # 2. 验证环境变量 JSON 格式
    if ! validate_env_config "$env_config_json"; then
        return 1
    fi

    # 3. 写入到 provider.json
    local temp_file=$(mktemp)
    if command -v jq >/dev/null 2>&1; then
        if [[ -f "$PROVIDER_CONFIG_FILE" ]]; then
            # 更新现有文件
            jq --arg name "$provider_name" --argjson env "$env_config_json" \
               '.[$name] = $env' "$PROVIDER_CONFIG_FILE" > "$temp_file"
        else
            # 创建新文件
            echo "{}" | jq --arg name "$provider_name" --argjson env "$env_config_json" \
               '. + {($name): $env}' > "$temp_file"
        fi

        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$PROVIDER_CONFIG_FILE"
            echo -e "${GREEN}已成功添加 provider: $provider_name${NC}"
        else
            echo -e "${RED}添加 provider 失败${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要安装 jq${NC}"
        rm -f "$temp_file"
        return 1
    fi
}

# 设置 token
set_token() {
    local provider="$1"
    local token="$2"

    if [[ -z "$provider" || -z "$token" ]]; then
        echo -e "${RED}错误: 请提供 provider 和 token${NC}"
        echo "用法: switch-claude set-token <provider> <token>"
        return 1
    fi

    # 验证 provider 是否存在
    if ! validate_provider "$provider"; then
        echo -e "${RED}错误: provider '$provider' 不存在${NC}"
        list_providers
        return 1
    fi

    # 清理 token
    token=$(clean_token "$token")

    # 更新 provider.json
    local temp_file=$(mktemp)
    if command -v jq >/dev/null 2>&1; then
        jq --arg provider "$provider" --arg token "$token" \
           '.[$provider].ANTHROPIC_AUTH_TOKEN = $token' \
           "$PROVIDER_CONFIG_FILE" > "$temp_file"

        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$PROVIDER_CONFIG_FILE"
            echo -e "${GREEN}已为 $provider 设置 token${NC}"
        else
            echo -e "${RED}设置 token 失败${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要安装 jq${NC}"
        rm -f "$temp_file"
        return 1
    fi
}

# 删除自定义 provider
remove_provider() {
    local provider="$1"

    if [[ -z "$provider" ]]; then
        echo -e "${RED}错误: 请提供 provider 名称${NC}"
        echo "用法: switch-claude remove-provider <provider>"
        return 1
    fi

    # 不能删除内置 provider
    case "$provider" in
        "glm"|"kimi"|"minimax")
            echo -e "${RED}错误: 不能删除内置 provider: $provider${NC}"
            return 1
            ;;
    esac

    if [[ ! -f "$PROVIDER_CONFIG_FILE" ]]; then
        echo -e "${YELLOW}provider.json 不存在${NC}"
        return 1
    fi

    # 检查 provider 是否存在
    if ! validate_provider "$provider"; then
        echo -e "${RED}错误: provider '$provider' 不存在${NC}"
        return 1
    fi

    # 确认删除
    read -p "确定要删除 provider '$provider' 吗？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消"
        return 0
    fi

    # 删除 provider
    local temp_file=$(mktemp)
    if command -v jq >/dev/null 2>&1; then
        jq "del(.$provider)" "$PROVIDER_CONFIG_FILE" > "$temp_file"

        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$PROVIDER_CONFIG_FILE"
            echo -e "${GREEN}已删除 provider: $provider${NC}"
        else
            echo -e "${RED}删除 provider 失败${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要安装 jq${NC}"
        rm -f "$temp_file"
        return 1
    fi
}

# 列出所有 provider
list_providers() {
    if [[ ! -f "$PROVIDER_CONFIG_FILE" ]]; then
        echo -e "${YELLOW}没有找到 provider.json${NC}"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "可用的 provider:"
        jq -r 'keys[]' "$PROVIDER_CONFIG_FILE" 2>/dev/null | while read -r p; do
            # 检查是否为内置 provider
            case "$p" in
                "glm"|"kimi"|"minimax")
                    echo "  - $p (内置)"
                    ;;
                *)
                    echo "  - $p (自定义)"
                    ;;
            esac
        done
    fi
}

# 提示用户选择保存位置
prompt_save_location() {
    local provider="$1"
    local token="$2"

    # 检查是否有 gum 命令可用
    if command -v gum >/dev/null 2>&1; then
        # 使用 gum 提供美观的确认界面
        gum confirm "保存到 Keychain? (推荐)" --affirmative "是" --negative "否" && \
            set_token_keychain "$provider" "$token" 2>/dev/null || \
            (gum confirm "保存到配置文件?" --affirmative "是" --negative "否" && \
             set_token "$provider" "$token" 2>/dev/null)
    else
        # 降级到原生 bash read
        read -p "保存到 Keychain? (推荐) (y/n): " save_choice
        save_choice=${save_choice:-n}

        if [[ "$save_choice" =~ ^[Yy] ]]; then
            set_token_keychain "$provider" "$token" 2>/dev/null
        else
            read -p "保存到配置文件? (y/n): " save_file_choice
            save_file_choice=${save_file_choice:-n}
            if [[ "$save_file_choice" =~ ^[Yy] ]]; then
                set_token "$provider" "$token" 2>/dev/null
            fi
        fi
    fi
}

# 备份配置文件
backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        ensure_token_dir
        local backup_file="$CONFIG_DIR/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CONFIG_FILE" "$backup_file"
        echo -e "${YELLOW}已备份配置文件到 ${backup_file}${NC}"
    fi
}

# 创建配置文件目录
ensure_config_dir() {
    local config_dir=$(dirname "$CONFIG_FILE")
    if [[ ! -d "$config_dir" ]]; then
        mkdir -p "$config_dir"
        echo -e "${YELLOW}已创建配置目录: $config_dir${NC}"
    fi
}

# 创建基础配置文件结构
create_base_config() {
    cat > "$CONFIG_FILE" << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {},
  "permissions": {
    "allow": [],
    "deny": []
  }
}
EOF
}

# 确保 token 配置目录存在
ensure_token_dir() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        echo -e "${YELLOW}已创建 token 配置目录: $CONFIG_DIR${NC}"
    fi
}

# 创建 tokens 配置文件
create_tokens_file() {
    ensure_token_dir
    
    if [[ ! -f "$TOKENS_FILE" ]]; then
        cat > "$TOKENS_FILE" << 'EOF'
{
  "glm": "",
  "kimi": "",
  "minimax": ""
}
EOF
        chmod 600 "$TOKENS_FILE"  # 仅用户可读写
        echo -e "${YELLOW}已创建 token 配置文件: $TOKENS_FILE${NC}"
        echo -e "${YELLOW}请使用 'switch-claude set-token' 命令设置您的 API tokens${NC}"
    fi
}

# 提示用户输入 token
prompt_for_token() {
    local provider="$1"
    local token=""

    # 提示用户输入 token
    while [[ -z "$token" ]]; do
        # token=$(gum input --placeholder "请输入 $provider token")
        read -p "请输入 $provider token: " token
        if [[ -z "$token" ]]; then
            echo -e "${RED}Token 不能为空，请重新输入${NC}"
        fi
    done

    # 清理 token
    token=$(clean_token "$token")

    # 询问用户选择保存位置
    prompt_save_location "$provider" "$token"

    # 返回 token
    echo "$token"
}

# 读取 token
read_token() {
    local provider="$1"

    # 1. 优先从 Keychain 读取
    local token=$(security find-generic-password -a "$USER" -s "switch-claude-$provider" -w 2>/dev/null)

    # 2. 如果 Keychain 没有，从环境变量读取
    if [[ -z "$token" ]]; then
        case "$provider" in
            "glm") token="$GLM_TOKEN" ;;
            "kimi") token="$KIMI_TOKEN" ;;
            "minimax") token="$MINIMAX_TOKEN" ;;
        esac
    fi

    # 3. 如果环境变量也没有，从 provider.json 读取
    if [[ -z "$token" && -f "$PROVIDER_CONFIG_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            token=$(jq -r ".$provider.ANTHROPIC_AUTH_TOKEN // empty" "$PROVIDER_CONFIG_FILE" 2>/dev/null)
        fi
    fi

    # 4. 如果所有方式都失败，提示用户输入
    if [[ -z "$token" ]]; then
        token=$(prompt_for_token "$provider")
    fi

    # 清理 token 并返回
    clean_token "$token"
}

# 设置 token 到 Keychain
set_token_keychain() {
    local provider="$1"
    local token="$2"

    # 检查系统是否支持 Keychain
    if ! is_command_available "set-keychain"; then
        show_os_specific_error "keychain" "set-keychain"
        return 1
    fi

    if [[ -z "$provider" || -z "$token" ]]; then
        echo -e "${RED}错误: 请提供 provider 和 token${NC}"
        return 1
    fi

    if ! validate_provider "$provider"; then
        echo -e "${RED}错误: 不支持的 provider '$provider'${NC}"
        return 1
    fi

    # 清理 token
    token=$(clean_token "$token")

    # 删除现有的（如果存在）
    security delete-generic-password -a "$USER" -s "switch-claude-$provider" >/dev/null 2>&1

    # 添加新的
    security add-generic-password -a "$USER" -s "switch-claude-$provider" -w "$token" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}存储到 Keychain 失败${NC}"
        return 1
    fi
}

# 清空 Keychain 中的 token
clear_token_keychain() {
    local provider="$1"

    # 检查系统是否支持 Keychain
    if ! is_command_available "clear-keychain"; then
        show_os_specific_error "keychain" "clear-keychain"
        return 1
    fi

    if [[ -z "$provider" ]]; then
        echo -e "${RED}错误: 请提供 provider${NC}"
        return 1
    fi

    if ! validate_provider "$provider"; then
        echo -e "${RED}错误: 不支持的 provider '$provider'${NC}"
        echo "支持的 provider: glm, kimi, minimax"
        return 1
    fi

    # 从 Keychain 删除
    security delete-generic-password -a "$USER" -s "switch-claude-$provider" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}已从 Keychain 中清空 $provider token${NC}"
    else
        echo -e "${YELLOW}Keychain 中可能没有 $provider token${NC}"
    fi
}

# 清空所有 Keychain 中的 tokens
clear_all_tokens_keychain() {
    # 检查系统是否支持 Keychain
    if ! is_command_available "clear-all-keychains"; then
        show_os_specific_error "keychain" "clear-all-keychains"
        return 1
    fi

    local count=0
    for provider in glm kimi minimax; do
        security delete-generic-password -a "$USER" -s "switch-claude-$provider" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            count=$((count + 1))
        fi
    done

    if [[ $count -gt 0 ]]; then
        echo -e "${GREEN}已从 Keychain 中清空 $count 个 token${NC}"
    else
        echo -e "${YELLOW}Keychain 中没有找到任何 token${NC}"
    fi
}

# 脱敏显示token（隐藏中间部分）
mask_token() {
    local token="$1"
    if [[ -z "$token" ]]; then
        echo "$token"
        return
    fi
    
    local token_len=${#token}
    if [[ $token_len -le 10 ]]; then
        # 短token，只显示前2个字符
        echo "${token:0:2}***"
    elif [[ $token_len -le 20 ]]; then
        # 中等长度token，显示前4个和后4个字符
        echo "${token:0:4}***${token: -4}"
    else
        # 长token，显示前6个和后4个字符
        echo "${token:0:6}***${token: -4}"
    fi
}

# 读取当前配置并显示
show_current() {
    echo -e "${BLUE}当前 Claude Code 配置:${NC}"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}配置文件不存在: $CONFIG_FILE${NC}"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "环境变量配置:"
        # 读取环境变量并对包含token的值进行脱敏
        while IFS='=' read -r key value; do
            if [[ "$key" =~ TOKEN|token ]]; then
                # 对token进行脱敏
                masked_value=$(mask_token "$value")
                echo "  $key: $masked_value"
            else
                echo "  $key: $value"
            fi
        done < <(jq -r '.env | to_entries[] | "\(.key)=\(.value)"' "$CONFIG_FILE" 2>/dev/null)
        
        # 如果没有环境变量，显示提示
        local env_count=$(jq -r '.env | length' "$CONFIG_FILE" 2>/dev/null)
        if [[ "$env_count" == "0" ]]; then
            echo "  (无环境变量配置)"
        fi
    else
        echo -e "${YELLOW}请安装 jq 以获得更好的显示效果，或直接查看配置文件:${NC}"
        echo "文件路径: $CONFIG_FILE"
        echo ""
        echo "环境变量配置:"
        
        # 提取环境变量部分并脱敏token
        local env_section=$(grep -A 50 '"env"' "$CONFIG_FILE" | grep -B 50 '}' | head -n -1 | tail -n +2)
        if [[ -n "$env_section" ]]; then
            echo "$env_section" | while IFS= read -r line; do
                if [[ "$line" =~ \"([^\"]+)\":[[:space:]]*\"([^\"]+)\" ]]; then
                    local key="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    if [[ "$key" =~ TOKEN|token ]]; then
                        local masked_value=$(mask_token "$value")
                        echo "    \"$key\": \"$masked_value\""
                    else
                        echo "  $line"
                    fi
                else
                    echo "  $line"
                fi
            done
        else
            echo "  (无环境变量配置)"
        fi
    fi
}

# 更新配置文件中的环境变量
update_config() {
    local model_name="$1"
    local env_config="$2"
    local launch_claude="$3"
    shift 3  # 移除前三个参数，剩余参数传递给 claude

    echo -e "${GREEN}切换到 $model_name 模型...${NC}"

    # 确保配置目录存在
    ensure_config_dir

    # 备份当前配置
    backup_config

    # 如果配置文件不存在，创建基础结构
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_base_config
    fi

    # 使用临时文件处理 JSON
    local temp_file=$(mktemp)

    if command -v jq >/dev/null 2>&1; then
        # 使用 jq 更新配置
        jq --argjson env "$env_config" '.env = $env' "$CONFIG_FILE" > "$temp_file"
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$CONFIG_FILE"
            echo -e "${GREEN}$model_name 配置已应用${NC}"

            # 如果指定了启动 claude，则启动
            if [[ "$launch_claude" == "true" ]]; then
                echo -e "${BLUE}正在启动 Claude Code...${NC}"
                if [[ $# -gt 0 ]]; then
                    # 有参数，将所有参数合并为一个字符串作为 prompt 传递
                    local prompt="$*"
                    claude "$prompt"
                else
                    # 无参数，直接启动 claude 交互模式
                    claude
                fi
            fi
        else
            echo -e "${RED}更新配置失败${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要安装 jq 来处理 JSON 配置文件${NC}"
        echo "请运行: brew install jq (macOS) 或 apt-get install jq (Ubuntu/Debian)"
        rm -f "$temp_file"
        return 1
    fi
}

# GLM 配置
switch_to_glm() {
    local launch_claude="$1"
    shift  # 移除第一个参数，剩余参数传递给 claude

    # 从 provider.json 读取配置
    local provider_config=$(read_provider_config "glm" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$provider_config" ]]; then
        echo -e "${RED}错误: 无法读取 GLM 配置${NC}"
        echo ""
        echo "请确保已运行: switch-claude init-provider-config"
        return 1
    fi

    # 读取 token（优先级：Keychain > env > provider.json > prompt）
    local token=$(read_token "glm")

    # 解析配置并替换 token
    local env_config=$(echo "$provider_config" | jq \
        --arg token "$token" \
        '.ANTHROPIC_AUTH_TOKEN = $token')

    update_config "GLM" "$env_config" "$launch_claude" "$@"
}

# Kimi 配置
switch_to_kimi() {
    local launch_claude="$1"
    shift  # 移除第一个参数，剩余参数传递给 claude

    # 从 provider.json 读取配置
    local provider_config=$(read_provider_config "kimi" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$provider_config" ]]; then
        echo -e "${RED}错误: 无法读取 Kimi 配置${NC}"
        echo ""
        echo "请确保已运行: switch-claude init-provider-config"
        return 1
    fi

    # 读取 token（优先级：Keychain > env > provider.json > prompt）
    local token=$(read_token "kimi")

    # 解析配置并替换 token
    local env_config=$(echo "$provider_config" | jq \
        --arg token "$token" \
        '.ANTHROPIC_AUTH_TOKEN = $token')

    update_config "Kimi" "$env_config" "$launch_claude" "$@"
}

# Minimax 配置
switch_to_minimax() {
    local launch_claude="$1"
    shift  # 移除第一个参数，剩余参数传递给 claude

    # 从 provider.json 读取配置
    local provider_config=$(read_provider_config "minimax" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$provider_config" ]]; then
        echo -e "${RED}错误: 无法读取 Minimax 配置${NC}"
        echo ""
        echo "请确保已运行: switch-claude init-provider-config"
        return 1
    fi

    # 读取 token（优先级：Keychain > env > provider.json > prompt）
    local token=$(read_token "minimax")

    # 解析配置并替换 token
    local env_config=$(echo "$provider_config" | jq \
        --arg token "$token" \
        '.ANTHROPIC_AUTH_TOKEN = $token')

    update_config "Minimax" "$env_config" "$launch_claude" "$@"
}

# 通用 provider 切换函数（用于自定义 provider）
switch_to_provider() {
    local provider="$1"
    local launch_claude="$2"
    shift 2  # 移除前两个参数，剩余参数传递给 claude

    # 检查 provider 是否有效
    if ! validate_provider "$provider"; then
        echo -e "${RED}错误: 未知的 provider '$provider'${NC}"
        echo ""
        list_providers
        return 1
    fi

    # 检查是否为内置 provider（内置 provider 有专门的函数）
    case "$provider" in
        "glm"|"kimi"|"minimax")
            echo -e "${YELLOW}警告: 内置 provider '$provider' 建议使用专用命令${NC}"
            ;;
    esac

    # 从 provider.json 读取配置
    local provider_config=$(read_provider_config "$provider" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$provider_config" ]]; then
        echo -e "${RED}错误: 无法读取 $provider 配置${NC}"
        echo ""
        echo "请确保已运行: switch-claude init-provider-config"
        return 1
    fi

    # 读取 token（优先级：Keychain > env > provider.json > prompt）
    local token=$(read_token "$provider")

    # 解析配置并替换 token
    local env_config=$(echo "$provider_config" | jq \
        --arg token "$token" \
        '.ANTHROPIC_AUTH_TOKEN = $token')

    update_config "$provider" "$env_config" "$launch_claude" "$@"
}

# 清空配置
clear_config() {
    # 检查是否有 gum 命令可用
    if command -v gum >/dev/null 2>&1; then
        # 使用 gum 创建美观的警告框
        local warning_message=$(gum style --border double --border-foreground red --padding "1 2" --bold --foreground red "警告：即将清空所有配置和数据" "
此操作将执行以下清空操作：
  1. 清空 ~/.claude/settings.json 中的环境变量
  2. 清空 ~/.config/switch-claude/ 文件夹中的所有文件
  3. 清空 Keychain 中的所有 switch-claude 创建的 model tokens

注意：此操作不可撤销！")

        # 显示警告信息
        echo "$warning_message"
        echo ""

        # 使用 gum 进行确认
        gum confirm "确定要继续清空所有配置吗？" --affirmative "确定清空" --negative "取消" || {
            echo -e "${YELLOW}已取消清空操作${NC}"
            return 0
        }
    else
        # 降级到原生 bash 界面
        echo -e "${YELLOW}=== 警告：即将清空所有配置和数据 ===${NC}"
        echo ""
        echo "此操作将执行以下清空操作："
        echo "  1. 清空 ~/.claude/settings.json 中的环境变量"
        echo "  2. 清空 ~/.config/switch-claude/ 文件夹中的所有文件"
        echo "  3. 清空 Keychain 中的所有 switch-claude 创建的 model tokens"
        echo ""
        echo -e "${RED}注意：此操作不可撤销！${NC}"
        echo ""

        # 询问用户确认
        read -p "确定要继续清空所有配置吗？(输入 'yes' 确认): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${YELLOW}已取消清空操作${NC}"
            return 0
        fi
    fi

    echo ""
    echo -e "${YELLOW}正在清空配置...${NC}"

    # 清空环境变量配置
    if [[ -f "$CONFIG_FILE" ]]; then
        local temp_file=$(mktemp)
        if command -v jq >/dev/null 2>&1; then
            jq '.env = {}' "$CONFIG_FILE" > "$temp_file"
            if [[ $? -eq 0 ]]; then
                mv "$temp_file" "$CONFIG_FILE"
            else
                echo -e "${RED}清空配置文件失败${NC}"
                rm -f "$temp_file"
                return 1
            fi
        else
            echo -e "${RED}错误: 需要安装 jq 来处理 JSON 配置文件${NC}"
            rm -f "$temp_file"
            return 1
        fi
    fi

    # 清空整个 ~/.config/switch-claude 目录
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}已清空配置目录: $CONFIG_DIR${NC}"
    fi

    # 清空 Keychain 中的所有 tokens
    clear_all_tokens_keychain

    echo ""
    echo -e "${GREEN}所有配置和 tokens 已清空完成${NC}"
}

# 检查依赖
check_dependencies() {
    local has_error=0

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}错误: 此脚本需要安装 jq${NC}"
        echo ""
        echo "安装方法:"
        echo "  macOS: brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  CentOS/RHEL: sudo yum install jq"
        echo ""
        has_error=1
    fi

    # 检查 gum 是否可用（可选）
    if ! command -v gum >/dev/null 2>&1; then
        echo -e "${YELLOW}提示: 安装 gum 可以获得更美观的交互界面${NC}"
        echo "  macOS: brew install gum"
        echo "  其他系统: https://github.com/charmbracelet/gum"
        echo ""
    fi

    return $has_error
}

# ========== 动态帮助信息生成 ==========

# 显示 macOS 专用帮助
show_macos_help() {
    cat << 'EOF'
Claude Code 模型切换脚本 (macOS)

用法:
  switch-claude [选项] [--launch]

模型切换选项:
  glm                    切换到 GLM 模型
  kimi                   切换到 Kimi 模型
  minimax                切换到 Minimax 模型
  <custom-provider>      切换到自定义 provider
  current                显示当前配置
  clear                  清空所有配置（需要确认）

Provider 管理选项:
  init-provider-config                初始化默认 provider.json
  show-provider-config                显示所有 provider 配置
  list-providers                      列出所有可用的 provider
  add-provider <name> <config>        添加新的自定义 provider
  set-token <provider> <token>        为 provider 设置 token
  remove-provider <provider>          删除自定义 provider

Token 管理选项:
  set-token <provider> <token>        设置 token 到 provider.json (推荐)
  set-keychain <provider> <token>     设置 token 到 Keychain (最安全) ⭐
  clear-keychain <provider>           清空 Keychain 中特定 provider 的 token
  clear-all-keychains                 清空 Keychain 中的所有 switch-claude 创建的 tokens

其他选项:
  --system-info     显示系统信息
  --launch          切换后自动启动 Claude Code
  help              显示此帮助信息

说明:
  - Token 优先级: Keychain > 环境变量 > provider.json
  - 每次切换前会自动备份当前配置
  - Provider 配置文件位置: ~/.config/switch-claude/provider.json
  - 推荐使用 Keychain 存储 token 以提高安全性
EOF
}

# 显示 Linux 专用帮助
show_linux_help() {
    cat << 'EOF'
Claude Code 模型切换脚本 (Linux)

用法:
  switch-claude [选项] [--launch]

模型切换选项:
  glm                    切换到 GLM 模型
  kimi                   切换到 Kimi 模型
  minimax                切换到 Minimax 模型
  <custom-provider>      切换到自定义 provider
  current                显示当前配置
  clear                  清空所有配置（需要确认）

Provider 管理选项:
  init-provider-config                初始化默认 provider.json
  show-provider-config                显示所有 provider 配置
  list-providers                      列出所有可用的 provider
  add-provider <name> <config>        添加新的自定义 provider
  set-token <provider> <token>        为 provider 设置 token (推荐) ⭐
  remove-provider <provider>          删除自定义 provider

Token 管理选项:
  set-token <provider> <token>        设置 token 到 provider.json (推荐)

可选 (GNOME Keyring):
  - 如果已安装 GNOME Keyring: sudo apt install gnome-keyring libsecret-tools
  - 可以使用 secret-tool 获得更好的安全性

其他选项:
  --system-info     显示系统信息
  --launch          切换后自动启动 Claude Code
  help              显示此帮助信息

说明:
  - Ubuntu/Debian 等 Linux 系统不支持 macOS Keychain
  - 推荐使用 'set-token' 命令存储到配置文件
  - Token 优先级: 环境变量 > provider.json > 提示输入
  - 每次切换前会自动备份当前配置
  - Provider 配置文件位置: ~/.config/switch-claude/provider.json
EOF
}

# 生成动态帮助
generate_dynamic_help() {
    case "$OS_TYPE" in
        "macos")
            show_macos_help
            ;;
        "linux")
            show_linux_help
            ;;
        *)
            # 通用帮助
            echo -e "${BLUE}Claude Code 模型切换脚本${NC}"
            echo ""
            echo "用法:"
            echo "  switch-claude [选项] [--launch]"
            echo ""
            echo "模型切换选项:"
            echo "  glm                    切换到 GLM 模型"
            echo "  kimi                   切换到 Kimi 模型"
            echo "  minimax                切换到 Minimax 模型"
            echo "  <custom-provider>      切换到自定义 provider"
            echo "  current                显示当前配置"
            echo "  clear                  清空所有配置"
            echo ""
            echo "Provider 管理选项:"
            echo "  init-provider-config   初始化默认 provider.json"
            echo "  show-provider-config   显示所有 provider 配置"
            echo "  list-providers         列出所有可用的 provider"
            echo "  add-provider <name> <config>   添加新的自定义 provider"
            echo "  set-token <provider> <token>   为 provider 设置 token"
            echo "  remove-provider <provider>     删除自定义 provider"
            echo ""
            echo "其他选项:"
            echo "  --system-info  显示系统信息"
            echo "  --launch       切换后自动启动 Claude Code"
            echo "  help           显示此帮助信息"
            echo ""
            echo "说明:"
            echo "  - 当前系统: $OS_TYPE"
            echo "  - 某些功能可能不可用"
            echo "  - 使用 --system-info 查看详细信息"
            ;;
    esac
}

# 显示使用帮助（动态生成）
show_help() {
    generate_dynamic_help
}

# ========== 命令可用性检查 ==========

# 检查命令在当前系统是否可用
is_command_available() {
    local cmd="$1"

    case "$cmd" in
        "set-keychain"|"clear-keychain"|"clear-all-keychains")
            # Keychain 仅在 macOS 可用
            [[ "$OS_TYPE" == "macos" && "$HAS_KEYCHAIN" == "true" ]]
            ;;
        "set-secret"|"get-secret"|"delete-secret")
            # secret-tool 仅在 Linux 且安装了 GNOME Keyring 时可用
            [[ "$OS_TYPE" == "linux" && "$HAS_SECRET_TOOL" == "true" ]]
            ;;
        *)
            # 其他命令在所有系统都可用
            return 0
            ;;
    esac
}

# 显示系统特定错误信息
show_os_specific_error() {
    local feature="$1"
    local feature_name="${2:-$feature}"

    echo -e "${RED}错误: '$feature_name' 在当前系统不可用${NC}"
    echo ""

    case "$OS_TYPE" in
        "macos")
            if [[ "$feature" == "keychain" ]]; then
                echo -e "${YELLOW}Keychain 是 macOS 的原生功能，但当前可能未正确配置${NC}"
            fi
            ;;
        "linux")
            case "$feature" in
                "keychain")
                    echo -e "${YELLOW}Keychain 是 macOS 专有功能，Linux 系统不支持${NC}"
                    echo ""
                    echo -e "${BLUE}替代方案:${NC}"
                    echo "  1. 使用 'set-token' 命令将 token 存储到配置文件"
                    echo "  2. 设置环境变量 (export GLM_TOKEN=your_token)"
                    echo "  3. 安装 GNOME Keyring: sudo apt install gnome-keyring libsecret-tools"
                    echo "     然后可以使用 'set-secret' 命令"
                    ;;
                *)
                    echo -e "${YELLOW}此功能在 Linux 上不可用${NC}"
                    ;;
            esac
            ;;
        "windows")
            echo -e "${YELLOW}Windows (WSL) 环境下某些功能可能受限${NC}"
            echo -e "${BLUE}  建议在 WSL2 中运行${NC}"
            ;;
    esac
}

# 主函数
main() {
    # 检查依赖
    if ! check_dependencies; then
        return 1
    fi

    # 检查和验证 provider 配置
    if ! check_provider_config; then
        return 1
    fi

    # Provider 管理命令（不使用 --launch 参数）
    case "${1:-}" in
        "init-provider-config"|"show-provider-config"|"add-provider"|"set-token"|"remove-provider"|"list-providers")
            case "$1" in
                "init-provider-config")
                    init_provider_config
                    ;;
                "show-provider-config")
                    show_provider_config
                    ;;
                "add-provider")
                    if [[ $# -ne 3 ]]; then
                        echo -e "${RED}错误: add-provider 需要 2 个参数${NC}"
                        echo "用法: switch-claude add-provider <provider_name> <env_config_json>"
                        echo ""
                        echo "示例:"
                        echo 'switch-claude add-provider MyProvider "{\"ANTHROPIC_AUTH_TOKEN\": \"\", \"ANTHROPIC_BASE_URL\": \"https://api.custom.com/anthropic\", \"ANTHROPIC_MODEL\": \"custom-model\"}"'
                        return 1
                    fi
                    add_provider "$2" "$3"
                    ;;
                "set-token")
                    if [[ $# -ne 3 ]]; then
                        echo -e "${RED}错误: set-token 需要 2 个参数${NC}"
                        echo "用法: switch-claude set-token <provider> <token>"
                        echo "支持的 provider: 查看 'switch-claude list-providers'"
                        return 1
                    fi
                    set_token "$2" "$3"
                    ;;
                "remove-provider")
                    if [[ $# -ne 2 ]]; then
                        echo -e "${RED}错误: remove-provider 需要 1 个参数${NC}"
                        echo "用法: switch-claude remove-provider <provider>"
                        return 1
                    fi
                    remove_provider "$2"
                    ;;
                "list-providers")
                    list_providers
                    ;;
            esac
            return $?
            ;;

        # Keychain 管理命令
        "set-keychain"|"clear-keychain"|"clear-all-keychains")
            case "$1" in
                "set-keychain")
                    if [[ $# -ne 3 ]]; then
                        echo -e "${RED}错误: set-keychain 需要 2 个参数${NC}"
                        echo "用法: switch-claude set-keychain <provider> <token>"
                        echo "支持的 provider: 查看 'switch-claude list-providers'"
                        return 1
                    fi
                    set_token_keychain "$2" "$3"
                    ;;
                "clear-keychain")
                    if [[ $# -ne 2 ]]; then
                        echo -e "${RED}错误: clear-keychain 需要 1 个参数${NC}"
                        echo "用法: switch-claude clear-keychain <provider>"
                        echo "支持的 provider: 查看 'switch-claude list-providers'"
                        return 1
                    fi
                    clear_token_keychain "$2"
                    ;;
                "clear-all-keychains")
                    clear_all_tokens_keychain
                    ;;
            esac
            return $?
            ;;
    esac

    # 检查是否需要启动 claude
    local launch_claude="false"
    local claude_args=()
    local model=""

    # 解析参数
    local found_launch=false
    local args=("$@")

    for ((i=0; i<${#args[@]}; i++)); do
        arg="${args[$i]}"

        if [[ "$found_launch" == true ]]; then
            # --launch 后面的所有参数都传递给 claude
            claude_args+=("$arg")
        elif [[ "$arg" == "--launch" ]]; then
            launch_claude="true"
            found_launch=true
        elif [[ "$arg" == "--system-info" ]]; then
            # 显示系统信息
            echo -e "${BLUE}系统信息:${NC}"
            echo "  操作系统: $OS_TYPE"
            echo "  jq: $HAS_JQ"
            echo "  Keychain: $HAS_KEYCHAIN"
            echo "  secret-tool: $HAS_SECRET_TOOL"
            echo "  gum: $HAS_GUM"
            echo ""
            case "$OS_TYPE" in
                "macos")
                    if [[ "$HAS_KEYCHAIN" == "true" ]]; then
                        echo -e "${GREEN}✓ macOS 完整功能可用 (Keychain)${NC}"
                        echo -e "${BLUE}  建议使用 'set-keychain' 获得最高安全性${NC}"
                    fi
                    ;;
                "linux")
                    if [[ "$HAS_KEYCHAIN" == "false" ]]; then
                        echo -e "${YELLOW}⚠ Linux 系统 (不支持 macOS Keychain)${NC}"
                        echo -e "${BLUE}  建议方案:${NC}"
                        echo -e "    1. 使用 'set-token' 存储到配置文件"
                        echo -e "    2. 或安装 GNOME Keyring: sudo apt install gnome-keyring libsecret-tools"
                    fi
                    if [[ "$HAS_SECRET_TOOL" == "true" ]]; then
                        echo -e "${GREEN}✓ GNOME Keyring 已安装，可使用 secret-tool${NC}"
                    fi
                    ;;
            esac
            return 0
        elif [[ -z "$model" ]]; then
            # 第一个非 --launch 参数是模型名
            model="$arg"
        fi
    done

    case "$model" in
        "glm")
            switch_to_glm "$launch_claude" "${claude_args[@]}"
            if [[ "$launch_claude" != "true" ]]; then
                show_current
            fi
            ;;
        "kimi")
            switch_to_kimi "$launch_claude" "${claude_args[@]}"
            if [[ "$launch_claude" != "true" ]]; then
                show_current
            fi
            ;;
        "minimax")
            switch_to_minimax "$launch_claude" "${claude_args[@]}"
            if [[ "$launch_claude" != "true" ]]; then
                show_current
            fi
            ;;
        "current")
            show_current
            ;;
        "clear")
            clear_config
            show_current
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        "")
            echo -e "${RED}错误: 请指定要切换的模型或操作${NC}"
            echo ""
            show_help
            return 1
            ;;
        *)
            # 尝试作为自定义 provider 处理
            if validate_provider "$model"; then
                switch_to_provider "$model" "$launch_claude" "${claude_args[@]}"
                if [[ "$launch_claude" != "true" ]]; then
                    show_current
                fi
            else
                echo -e "${RED}错误: 未知的选项 '$model'${NC}"
                echo ""
                list_providers
                return 1
            fi
            ;;
    esac
}

# 运行主函数
main "$@"