# Homebrew Tools

Claude Code 模型切换工具的 Homebrew 包集合。

## 主要工具

### Switch Claude

一个强大的 Claude Code 模型切换脚本，支持在 GLM、Kimi、Minimax 等模型之间快速切换。

## 📦 安装

```bash
# 添加 tap
brew tap yinzhenyu-su/homebrew-tools

# 安装 switch-claude
brew install switch-claude
```

## 🚀 Switch Claude 使用指南

### 基本用法

```bash
# 显示帮助
switch-claude help

# 显示当前配置
switch-claude current

# 切换到不同模型
switch-claude glm      # 切换到 GLM 模型
switch-claude kimi     # 切换到 Kimi 模型
switch-claude minimax  # 切换到 Minimax 模型
```

### 🔑 Token 管理

首次使用需要设置 API tokens：

```bash
# 推荐：使用 provider.json 存储
switch-claude set-token glm "your_glm_token"
switch-claude set-token kimi "your_kimi_token"
switch-claude set-token minimax "your_minimax_token"

# 最安全：使用 Keychain 存储（macOS）
switch-claude set-keychain glm "your_glm_token"
switch-claude set-keychain kimi "your_kimi_token"
switch-claude set-keychain minimax "your_minimax_token"
```

脚本会按照下方“[🔐 Token 优先级](#-token-优先级)”章节所述的顺序查找凭证，若所有来源都为空会提示你在终端中输入 token。macOS 用户优先推荐 `set-keychain`，其它平台可使用 `set-token` 写入 `provider.json`，环境变量适合临时调试。

### 📝 Provider 配置管理

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

### 🔧 自定义 Provider

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

### 🌐 跨平台功能

```bash
# 查看系统信息
switch-claude --system-info

# 动态帮助信息（根据操作系统显示不同内容）
switch-claude help
```

### 高级用法

```bash
# 切换并启动 Claude Code
switch-claude glm --launch

# 切换并发送消息
switch-claude kimi --launch "你好，帮我写个Python脚本"

# 清空所有配置
switch-claude clear
```

`--launch` 会在切换成功后调用 `claude` CLI；跟在 `--launch` 之后的任何文本都会作为一次性提示词转发给 Claude。

### ⚠️ 配置清理

`switch-claude clear` 会在交互确认后清空 `~/.claude/settings.json` 中的环境变量、删除整个 `~/.config/switch-claude/` 目录，并在 macOS 上移除以 `switch-claude-<provider>` 命名的 Keychain 条目；如果系统不支持 Keychain，会给出相应提示。安装了 [gum](https://github.com/charmbracelet/gum) 时将显示确认弹窗，否则使用终端输入 `yes` 确认。

### 别名命令

```bash
claude-switch glm        # 等同于 switch-claude glm
sc kimi                  # 等同于 switch-claude kimi
```

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

## 📋 依赖要求

- [jq](https://stedolan.github.io/jq/) - 必需，Homebrew Formula 会自动安装；手动运行脚本前请确保 `jq` 可用。
- [Claude Code CLI](https://claude.ai/code) - 需预先安装并确保 `claude` 命令在 `PATH` 中，否则 `--launch` 无法工作。
- [gum](https://github.com/charmbracelet/gum) - 可选，提供更友好的交互提示；缺失时脚本会自动降级为 shell 提示。

## 🧪 测试

### 运行测试套件

```bash
# 运行所有测试
bash tests/run-all-tests.sh

# 运行快速测试（适用于 macOS/Linux）
bash tests/quick-test.sh

# 运行错误处理测试
bash tests/test-errors.sh

# 运行集成测试
bash tests/test-integration.sh
```

运行 `tests/run-all-tests.sh` 时会先显示测试菜单，可通过 `printf '1\n' | bash tests/run-all-tests.sh` 在 CI 场景中直接选择“运行所有测试”。

### 测试内容概览

- **quick-test.sh**: 覆盖帮助信息、默认配置生成、provider 管理、Keychain 操作与模型切换等基础行为。
- **test-errors.sh**: 构造非法 JSON、无效参数、缺失依赖等异常场景，验证错误提示是否准确。
- **test-integration.sh**: 以七个端到端场景模拟真实使用流程（首次初始化、自定义 provider、Token 优先级、批量操作等）。
- **test-report.html**: `run-all-tests.sh` 结束后生成的可视化报告，包含统计概览和时间戳。

### 测试亮点

- ✅ 自动检测操作系统并在不支持的功能上回退或跳过。
- ✅ 对 token、配置文件和 Keychain 的读写进行了大量断言，覆盖 50+ 关键检查点。
- ✅ 所有脚本在测试结束时清理环境，避免污染用户配置。
- ✅ 支持在 macOS 上完整验证 Keychain 流程，在其它平台输出替代建议。

## 👨‍💻 开发

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/yinzhenyu-su/homebrew-tools.git
cd homebrew-tools

# 运行脚本
./scripts/switch-claude.sh help

# 运行完整测试套件
bash tests/run-all-tests.sh
```

### 贡献指南

1. Fork 这个仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

### 测试要求

提交 PR 前请确保：

- [ ] 运行完整测试套件：`bash tests/run-all-tests.sh`
- [ ] 确认 quick/errors/integration 三个脚本全部通过
- [ ] 跨平台兼容性（macOS/Linux）
- [ ] 更新相关文档

## 🗑️ 卸载

```bash
brew uninstall switch-claude
brew untap yinzhenyu-su/homebrew-tools
```

## 📄 许可证

MIT License

## 🔗 相关链接

- [Claude Code 官方文档](https://docs.anthropic.com/claude/docs)
- [Homebrew 官方文档](https://docs.brew.sh/)
- [项目 Issues](https://github.com/yinzhenyu-su/homebrew-tools/issues)
- [测试套件文档](tests/README.md)

## 📊 版本历史

### v2.0.1 (2025-11-14)

**亮点:**

- ✨ 新增平台感知帮助与 `--system-info`，按系统展示命令可用性。
- ✨ provider.json 支持自动初始化与严格 JSON 校验，自定义 provider 流程更稳健。
- 🔒 Token 查找顺序统一为 Keychain → 环境变量 → provider.json → 交互式输入，并在 `current` 中脱敏显示。
- ⚙️ `clear` 命令加入交互确认并扩展至清理 Keychain/配置目录。
- 🧪 扩展测试套件覆盖首次使用、自定义 provider、批量操作与异常场景。

### v1.0.3 (2025-11-09)

**重大更新:**

- ✨ 跨平台功能检测模块
- ✨ 动态帮助信息生成
- ✨ 命令可用性检查
- ✨ HTML 测试报告生成
- ✨ 完整测试套件（45个测试）

**功能增强:**

- 🔧 Provider 配置管理
- 🔧 自定义 Provider 支持
- 🔧 Token 优先级验证
- 🔧 配置备份功能
- 🔧 智能错误处理

**测试优化:**

- 🧪 7个完整集成测试场景
- 🧪 跨平台自动适配
- 🧪 智能跳过不支持功能
- 🧪 测试结果实时汇总

**文档完善:**

- 📚 完整的测试套件文档
