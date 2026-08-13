# Switch Claude 使用指南

Switch Claude 是一个强大的 Claude Code 模型切换脚本，支持在 GLM、Kimi、Minimax 等模型之间快速切换。通过 Homebrew 安装后，`switch-claude`、`claude-switch`、`sc` 三个命令等价。

## 基本用法

```bash
# 显示帮助 (或 sc help)
switch-claude help

# 显示当前配置 (或 sc current)
switch-claude current

# 切换到不同模型
switch-claude glm      # 切换到 GLM 模型 (或 sc glm)
switch-claude kimi     # 切换到 Kimi 模型 (或 sc kimi)
switch-claude minimax  # 切换到 Minimax 模型 (或 sc minimax)
```

## 🔑 Token 管理

首次使用需要设置 API tokens：

```bash
# 推荐：使用 provider.json 存储
switch-claude set-token glm "your_glm_token"      # 设置 GLM token (或 sc set-token glm "your_glm_token")
switch-claude set-token kimi "your_kimi_token"    # 设置 Kimi token (或 sc set-token kimi "your_kimi_token")
switch-claude set-token minimax "your_minimax_token"  # 设置 Minimax token (或 sc set-token minimax "your_minimax_token")

# 最安全：使用 Keychain 存储（macOS）
switch-claude set-keychain glm "your_glm_token"      # Keychain 存储 GLM token (或 sc set-keychain glm "your_glm_token")
switch-claude set-keychain kimi "your_kimi_token"    # Keychain 存储 Kimi token (或 sc set-keychain kimi "your_kimi_token")
switch-claude set-keychain minimax "your_minimax_token"  # Keychain 存储 Minimax token (或 sc set-keychain minimax "your_minimax_token")
```

脚本会按照下方"[🔐 Token 优先级](#-token-优先级)"章节所述的顺序查找凭证，若所有来源都为空会提示你在终端中输入 token。macOS 用户优先推荐 `set-keychain`，其它平台可使用 `set-token` 写入 `provider.json`，环境变量适合临时调试。

## 📝 Provider 配置管理

新版本支持从 `provider.json` 配置文件读取模型配置，实现更灵活的管理：

```bash
# 初始化默认 provider 配置
switch-claude init-provider-config

# 列出所有可用的 provider
switch-claude list-providers

# 显示所有 provider 配置
switch-claude show-provider-config

# 为特定 provider 设置 token
switch-claude set-token glm "your_token"
```

首次执行 `switch-claude list-providers` 或任何依赖 provider 的命令时，脚本会自动初始化 `~/.config/switch-claude/provider.json` 并写入三个内置配置。`switch-claude init-provider-config` 可在确认后重新生成该文件，而 `show-provider-config` 会对 token 做脱敏处理，方便安全排查。

## 🔧 自定义 Provider

支持添加自定义的模型提供商：

```bash
# 添加自定义 provider
switch-claude add-provider MyAPI '{
  "ANTHROPIC_AUTH_TOKEN": "",
  "ANTHROPIC_BASE_URL": "https://api.custom.com/anthropic",
  "ANTHROPIC_MODEL": "custom-model"
}'

# 删除自定义 provider
switch-claude remove-provider MyAPI

# 切换到自定义 provider
switch-claude MyAPI --launch
```

**自定义 Provider 要求**：

- Provider 名称只能包含英文字母和数字
- 必须包含 `ANTHROPIC_BASE_URL` 字段
- 至少需要配置一个模型字段（`ANTHROPIC_MODEL` 或 `ANTHROPIC_DEFAULT_*_MODEL`）
- 不能覆盖内置的 provider（glm、kimi、minimax）

## 🌐 跨平台功能

```bash
# 查看系统信息
switch-claude --system-info

# 动态帮助信息（根据操作系统显示不同内容）
switch-claude help
```

## 高级用法

```bash
# 切换并启动 Claude Code
switch-claude glm --launch

# 切换并发送消息
switch-claude kimi --launch "你好，帮我写个Python脚本"

# 清空所有配置
switch-claude clear
```

`--launch` 会在切换成功后调用 `claude` CLI；跟在 `--launch` 之后的任何文本都会作为一次性提示词转发给 Claude。

## ⚠️ 配置清理

`switch-claude clear` 会在交互确认后清空 `~/.claude/settings.json` 中的环境变量、删除整个 `~/.config/switch-claude/` 目录，并在 macOS 上移除以 `switch-claude-<provider>` 命名的 Keychain 条目；如果系统不支持 Keychain，会给出相应提示。安装了 [gum](https://github.com/charmbracelet/gum) 时将显示确认弹窗，否则使用终端输入 `yes` 确认。

## 别名命令

```bash
claude-switch glm        # 等同于 switch-claude glm
sc kimi                  # 等同于 switch-claude kimi
```

## 🔧 支持的模型

- **GLM**: 智谱 AI 的 GLM 系列模型（glm-4.5-air, glm-4.6）
- **Kimi**: 月之暗面的 Kimi 模型（kimi-k2-turbo-preview）
- **Minimax**: MiniMax 的模型（MiniMax-M2）

## 🔐 Token 优先级

脚本按以下优先级读取 token：

1. **macOS Keychain** (最安全，推荐)
2. **环境变量** (`$GLM_TOKEN`, `$KIMI_TOKEN`, `$MINIMAX_TOKEN`)
3. **Provider 配置文件** (`~/.config/switch-claude/provider.json`)
4. **提示用户输入** (如果以上都未设置)

当需要交互式输入 token 时，脚本会先询问是否保存到 Keychain（仅 macOS）或 `provider.json`，若拒绝则仅在本次切换中使用该 token。

## 📁 配置文件位置

- **Claude Code 配置**: `~/.claude/settings.json`
- **Provider 配置**: `~/.config/switch-claude/provider.json`
- **配置备份**: `~/.config/switch-claude/settings.json.backup.YYYYMMDD_HHMMSS`
- **Keychain (macOS)**: `switch-claude-<provider>` 名称的钥匙串条目
- **Token 配置 (旧版兼容)**: `~/.config/switch-claude/tokens.json`（现版本不会自动生成，仅保留向后兼容）

## ✨ 功能特性

- ✅ **跨平台适配**: 自动识别 macOS/Linux，并输出对应的帮助与命令可用性提示。
- ✅ **系统洞察**: `switch-claude help` 与 `--system-info` 动态展示依赖状态、Keychain/secret-tool 支持情况。
- ✅ **多源 Token 管理**: 按 Keychain → 环境变量 → provider.json → 终端输入 的顺序查找，并对 `current` 输出的 token 自动脱敏。
- ✅ **默认与自定义 Provider**: 首次运行自动生成默认配置，支持校验 JSON、批量添加/删除和安全确认。
- ✅ **配置备份机制**: 切换前自动备份为 `~/.config/switch-claude/settings.json.backup.*`，方便手动回滚。
- ✅ **Claude CLI 集成**: `--launch` 支持直接唤起 `claude` 命令并可附带一次性 prompt。
- ✅ **交互式清理**: `clear` 命令在确认后清空配置目录并清理 macOS Keychain。
- ✅ **丰富别名**: Homebrew 安装同时提供 `switch-claude`、`claude-switch` 与 `sc` 三个入口。
- ✅ **可选美化交互**: 检测到 [gum](https://github.com/charmbracelet/gum) 时自动启用更友好的确认/提示界面。
