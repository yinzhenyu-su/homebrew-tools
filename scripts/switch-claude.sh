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

# 验证 provider 是否有效
validate_provider() {
    local provider="$1"
    case "$provider" in
        "glm"|"kimi"|"minimax") return 0 ;;
        *) return 1 ;;
    esac
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

    # 优先从 Keychain 读取
    local token=$(security find-generic-password -a "$USER" -s "switch-claude-$provider" -w 2>/dev/null)

    # 如果 Keychain 没有，从文件读取
    if [[ -z "$token" && -f "$TOKENS_FILE" ]]; then
        if command -v jq >/dev/null 2>&1; then
            token=$(jq -r ".$provider // empty" "$TOKENS_FILE" 2>/dev/null)
        fi
    fi

    # 如果还是没有，从环境变量读取
    if [[ -z "$token" ]]; then
        case "$provider" in
            "glm") token="$GLM_TOKEN" ;;
            "kimi") token="$KIMI_TOKEN" ;;
            "minimax") token="$MINIMAX_TOKEN" ;;
        esac
    fi

    # 如果所有方式都失败，提示用户输入
    if [[ -z "$token" ]]; then
        token=$(prompt_for_token "$provider")
    fi

    # 清理 token 并返回
    clean_token "$token"
}

# 设置 token 到文件
set_token() {
    local provider="$1"
    local token="$2"

    if [[ -z "$provider" || -z "$token" ]]; then
        echo -e "${RED}错误: 请提供 provider 和 token${NC}"
        return 1
    fi

    if ! validate_provider "$provider"; then
        echo -e "${RED}错误: 不支持的 provider '$provider'${NC}"
        echo "支持的 provider: glm, kimi, minimax"
        return 1
    fi

    # 清理 token
    token=$(clean_token "$token")

    create_tokens_file

    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg provider "$provider" --arg token "$token" '.[$provider] = $token' "$TOKENS_FILE" > "$temp_file"
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$TOKENS_FILE"
            chmod 600 "$TOKENS_FILE"
        else
            echo -e "${RED}设置 token 失败${NC}"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要安装 jq 来处理 JSON 配置文件${NC}"
        return 1
    fi
}

# 设置 token 到 Keychain
set_token_keychain() {
    local provider="$1"
    local token="$2"

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
    security delete-generic-password -a "$USER" -s "switch-claude-$provider" 2>/dev/null

    # 添加新的
    security add-generic-password -a "$USER" -s "switch-claude-$provider" -w "$token" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}存储到 Keychain 失败${NC}"
        return 1
    fi
}

# 清空 Keychain 中的 token
clear_token_keychain() {
    local provider="$1"

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
    security delete-generic-password -a "$USER" -s "switch-claude-$provider" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}已从 Keychain 中清空 $provider token${NC}"
    else
        echo -e "${YELLOW}Keychain 中可能没有 $provider token${NC}"
    fi
}

# 清空所有 Keychain 中的 tokens
clear_all_tokens_keychain() {
    local count=0
    for provider in glm kimi minimax; do
        security delete-generic-password -a "$USER" -s "switch-claude-$provider" 2>/dev/null
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

# 显示 token 状态
show_token_status() {
    local provider="$1"

    if [[ -n "$provider" ]]; then
        # 显示特定 provider 的 token
        local token=$(read_token "$provider")
        if [[ -n "$token" ]]; then
            echo -e "${GREEN}$provider token: ${token:0:10}...${token: -4}${NC}"
        else
            echo -e "${YELLOW}$provider token: 未设置${NC}"
        fi
    else
        # 显示所有 provider 的 token 状态
        echo -e "${BLUE}Token 状态:${NC}"
        for p in glm kimi minimax; do
            local token=$(read_token "$p")
            if [[ -n "$token" ]]; then
                echo -e "  ${GREEN}$p: ${token:0:10}...${token: -4}${NC}"
            else
                echo -e "  ${YELLOW}$p: 未设置${NC}"
            fi
        done
        echo ""
        echo -e "${YELLOW}设置 token 的方法:${NC}"
        echo "  switch-claude set-token <provider> <token>      # 存储到文件"
        echo "  switch-claude set-keychain <provider> <token>   # 存储到 Keychain (推荐)"
        echo "  export <PROVIDER>_TOKEN=<token>                 # 设置环境变量"
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

    local token=$(read_token "glm")

    # 使用 jq 构建 JSON 配置
    local env_config=$(jq -n \
        --arg token "$token" \
        --arg base_url "https://open.bigmodel.cn/api/anthropic" \
        --arg timeout "3000000" \
        --arg disable_traffic "1" \
        --arg haiku_model "glm-4.5-air" \
        --arg sonnet_model "glm-4.6" \
        --arg opus_model "glm-4.6" \
        '{
            ANTHROPIC_AUTH_TOKEN: $token,
            ANTHROPIC_BASE_URL: $base_url,
            API_TIMEOUT_MS: $timeout,
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: $disable_traffic,
            ANTHROPIC_DEFAULT_HAIKU_MODEL: $haiku_model,
            ANTHROPIC_DEFAULT_SONNET_MODEL: $sonnet_model,
            ANTHROPIC_DEFAULT_OPUS_MODEL: $opus_model
        }')

    update_config "GLM" "$env_config" "$launch_claude" "$@"
}

# Kimi 配置
switch_to_kimi() {
    local launch_claude="$1"
    shift  # 移除第一个参数，剩余参数传递给 claude

    local token=$(read_token "kimi")

    # 使用 jq 构建 JSON 配置
    local env_config=$(jq -n \
        --arg token "$token" \
        --arg base_url "https://api.moonshot.cn/anthropic" \
        --arg model "kimi-k2-turbo-preview" \
        --arg small_model "kimi-k2-turbo-preview" \
        '{
            ANTHROPIC_BASE_URL: $base_url,
            ANTHROPIC_AUTH_TOKEN: $token,
            ANTHROPIC_MODEL: $model,
            ANTHROPIC_SMALL_FAST_MODEL: $small_model
        }')

    update_config "Kimi" "$env_config" "$launch_claude" "$@"
}

# Minimax 配置
switch_to_minimax() {
    local launch_claude="$1"
    shift  # 移除第一个参数，剩余参数传递给 claude

    local token=$(read_token "minimax")

    # 使用 jq 构建 JSON 配置
    local env_config=$(jq -n \
        --arg token "$token" \
        --arg base_url "https://api.minimaxi.com/anthropic" \
        --arg timeout "3000000" \
        --arg disable_traffic "1" \
        --arg model "MiniMax-M2" \
        --arg small_model "MiniMax-M2" \
        --arg sonnet_model "MiniMax-M2" \
        --arg opus_model "MiniMax-M2" \
        --arg haiku_model "MiniMax-M2" \
        '{
            ANTHROPIC_BASE_URL: $base_url,
            ANTHROPIC_AUTH_TOKEN: $token,
            API_TIMEOUT_MS: $timeout,
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: $disable_traffic,
            ANTHROPIC_MODEL: $model,
            ANTHROPIC_SMALL_FAST_MODEL: $small_model,
            ANTHROPIC_DEFAULT_SONNET_MODEL: $sonnet_model,
            ANTHROPIC_DEFAULT_OPUS_MODEL: $opus_model,
            ANTHROPIC_DEFAULT_HAIKU_MODEL: $haiku_model
        }')

    update_config "Minimax" "$env_config" "$launch_claude" "$@"
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

# 显示使用帮助
show_help() {
    echo -e "${BLUE}Claude Code 模型切换脚本${NC}"
    echo ""
    echo "用法:"
    echo "  switch-claude [选项] [--launch]"
    echo ""
    echo "模型切换选项:"
    echo "  glm      切换到 GLM 模型"
    echo "  kimi     切换到 Kimi 模型"
    echo "  minimax  切换到 Minimax 模型"
    echo "  current  显示当前配置"
    echo "  clear    清空所有配置（需要确认）"
    echo ""
    echo "Token 管理选项:"
    echo "  set-token <provider> <token>           设置 token 到配置文件"
    echo "  set-keychain <provider> <token>        设置 token 到 Keychain (推荐)"
    echo "  show-tokens                            显示所有 token 状态"
    echo "  show-token <provider>                  显示特定 provider 的 token 状态"
    echo "  clear-keychain <provider>              清空 Keychain 中特定 provider 的 token"
    echo "  clear-all-keychains                    清空 Keychain 中的所有 switch-claude 创建的 tokens"
    echo ""
    echo "其他选项:"
    echo "  help     显示此帮助信息"
    echo ""
    echo "参数:"
    echo "  --launch  切换后自动启动 Claude Code"
    echo ""
    echo "模型切换示例:"
    echo "  switch-claude glm                      # 切换到 GLM"
    echo "  switch-claude kimi                     # 切换到 Kimi"
    echo "  switch-claude minimax                  # 切换到 Minimax"
    echo "  switch-claude glm --launch             # 切换到 GLM 并启动 Claude Code"
    echo "  switch-claude kimi --launch 你好       # 切换到 Kimi 并启动 Claude Code，发送消息'你好'"
    echo "  switch-claude minimax --launch 帮我写个Python脚本  # 切换到 Minimax 并启动 Claude Code，发送请求"
    echo ""
    echo "Token 管理示例:"
    echo "  switch-claude set-token glm sk-xxx...            # 设置 GLM token 到文件"
    echo "  switch-claude set-keychain kimi sk-yyy...        # 设置 Kimi token 到 Keychain"
    echo "  switch-claude show-tokens                        # 显示所有 token 状态"
    echo "  switch-claude show-token glm                     # 显示 GLM token 状态"
    echo "  switch-claude clear-keychain kimi                # 清空 Keychain 中 Kimi token"
    echo "  switch-claude clear-all-keychains                # 清空 Keychain 中的所有 switch-claude 创建的 tokens"
    echo ""
    echo -e "${YELLOW}说明:${NC}"
    echo "  - 此脚本通过修改 ~/.claude/settings.json 文件来切换模型"
    echo "  - Token 优先级: Keychain > 配置文件 > 环境变量"
    echo "  - 每次切换前会自动备份当前配置"
    echo "  - 需要安装 jq 工具来处理 JSON 配置文件"
    echo "  - 使用 --launch 参数可在切换后自动启动 Claude Code"
    echo "  - --launch 后的参数会直接传递给 claude 命令，就像直接运行 claude 一样"
    echo "  - Token 配置文件位置: ~/.config/switch-claude/tokens.json"
    echo "  - 推荐使用 Keychain 存储 token 以提高安全性"
    echo "  - clear 命令会清空所有配置（包括 ~/.config/switch-claude 目录），需要用户确认"
}

# 主函数
main() {
    # 检查依赖
    if ! check_dependencies; then
        return 1
    fi

    # Token 管理命令（不使用 --launch 参数）
    case "${1:-}" in
        "set-token"|"set-keychain"|"show-tokens"|"show-token"|"clear-keychain"|"clear-all-keychains")
            case "$1" in
                "set-token")
                    if [[ $# -ne 3 ]]; then
                        echo -e "${RED}错误: set-token 需要 2 个参数${NC}"
                        echo "用法: switch-claude set-token <provider> <token>"
                        echo "支持的 provider: glm, kimi, minimax"
                        return 1
                    fi
                    set_token "$2" "$3"
                    ;;
                "set-keychain")
                    if [[ $# -ne 3 ]]; then
                        echo -e "${RED}错误: set-keychain 需要 2 个参数${NC}"
                        echo "用法: switch-claude set-keychain <provider> <token>"
                        echo "支持的 provider: glm, kimi, minimax"
                        return 1
                    fi
                    set_token_keychain "$2" "$3"
                    ;;
                "show-tokens")
                    show_token_status
                    ;;
                "show-token")
                    if [[ $# -ne 2 ]]; then
                        echo -e "${RED}错误: show-token 需要 1 个参数${NC}"
                        echo "用法: switch-claude show-token <provider>"
                        echo "支持的 provider: glm, kimi, minimax"
                        return 1
                    fi
                    show_token_status "$2"
                    ;;
                "clear-keychain")
                    if [[ $# -ne 2 ]]; then
                        echo -e "${RED}错误: clear-keychain 需要 1 个参数${NC}"
                        echo "用法: switch-claude clear-keychain <provider>"
                        echo "支持的 provider: glm, kimi, minimax"
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
            echo -e "${RED}错误: 未知的选项 '$model'${NC}"
            echo ""
            show_help
            return 1
            ;;
    esac
}

# 运行主函数
main "$@"