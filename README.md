# Homebrew Tools

Claude Code 模型切换工具的 Homebrew 包集合。

## 主要工具

### Switch Claude

一个强大的 Claude Code 模型切换脚本，支持在 GLM、Kimi、Minimax 等模型之间快速切换。

## 项目结构

```text
homebrew-tools/
├── README.md                    # 项目主文档
├── Formula/                     # Homebrew Formula 定义
│   └── switch-claude.rb        # switch-claude 包定义
├── scripts/                     # 主要脚本文件
│   └── switch-claude.sh        # Claude Code 模型切换脚本
├── docs/                        # 文档目录
│   └── STRUCTURE.md            # 项目结构说明
├── tests/                       # 测试文件
│   ├── README.md               # 测试套件文档
│   ├── run-all-tests.sh        # 测试套件主脚本
│   ├── quick-test.sh           # 快速功能测试
│   ├── test-errors.sh          # 错误处理测试
│   ├── test-integration.sh     # 集成测试
│   └── test-report.html        # 生成的HTML测试报告
└── .github/                     # GitHub 配置
    └── workflows/              # GitHub Actions 工作流
```

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

**Token 存储方式优先级**：
1. **Keychain** - 最安全，适合敏感信息
2. **provider.json** - 推荐，管理更灵活
3. **环境变量** - 适合临时使用

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

**系统信息示例:**
```
系统信息:
  操作系统: macos
  jq: ✓ 已安装
  Keychain: ✓ 可用
  secret-tool: ✗ 不可用
  gum: ✓ 已安装
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

### 别名命令

```bash
claude-switch glm        # 等同于 switch-claude glm
sc kimi                  # 等同于 switch-claude kimi
```

## ✨ 功能特性

- ✅ **跨平台支持**: 自动检测 macOS/Linux/Windows，智能适配功能
- ✅ **安全的 Token 管理**: 支持 Keychain、provider.json、环境变量三种方式
- ✅ **多模型支持**: GLM、Kimi、Minimax 及自定义 provider
- ✅ **Provider 配置**: 支持从 `provider.json` 文件读取配置，管理更灵活
- ✅ **自定义 Provider**: 可添加任意自定义模型提供商
- ✅ **配置备份**: 每次切换前自动备份
- ✅ **快速启动**: 支持切换后直接启动 Claude Code
- ✅ **别名支持**: `switch-claude`、`claude-switch`、`sc`
- ✅ **动态帮助**: 根据操作系统显示平台特定帮助信息
- ✅ **命令可用性检查**: 智能检测并提示平台不支持的功能
- ✅ **详细帮助**: 完整的使用说明和示例
- ✅ **简洁明了**: 精简命令，避免功能重复

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

## 📁 配置文件位置

- **Claude Code 配置**: `~/.claude/settings.json`
- **Provider 配置**: `~/.config/switch-claude/provider.json`
- **Token 配置 (旧版兼容)**: `~/.config/switch-claude/tokens.json`
- **配置备份**: `~/.claude/settings.json.backup.YYYYMMDD_HHMMSS`

## 📋 依赖要求

- [jq](https://stedolan.github.io/jq/) - JSON 处理工具（会自动安装）
- [Claude Code](https://claude.ai/code) - 需要预先安装

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

### 测试覆盖率

- **快速功能测试**: 15个测试，验证基本功能
- **错误处理测试**: 19个测试，验证各种异常场景
- **集成测试**: 11个测试，验证端到端工作流（7个完整场景）
- **总测试数**: 45个测试
- **通过率**: 100%
- **跨平台支持**: macOS/Linux 自动适配

### 测试特性

- ✅ 跨平台自动检测
- ✅ 智能跳过平台不支持的测试
- ✅ 完整的错误场景验证
- ✅ Token 优先级验证
- ✅ HTML 测试报告生成
- ✅ 测试结果实时汇总

## 👨‍💻 开发

### 本地开发

```bash
# 克隆仓库
git clone https://github.com/yinzhenyu-su/homebrew-tools.git
cd homebrew-tools

# 运行脚本
./scripts/switch-claude.sh help

# 测试 Formula
./tests/test-formula.sh

# 运行完整测试套件
bash tests/run-all-tests.sh
```

### 跨平台开发

```bash
# 平台检测模块
source scripts/platform-detector.sh
echo "OS_TYPE: $OS_TYPE"
echo "HAS_KEYCHAIN: $HAS_KEYCHAIN"

# 测试命令可用性
is_command_available "set-keychain"  # macOS: true, Linux: false
```

## 🚀 发布管理

### 开发者发布流程

如果您是项目维护者，可以使用以下命令发布新版本：

```bash
# 发布补丁版本 (修复bug)
./scripts/release.sh patch

# 发布次要版本 (新功能)
./scripts/release.sh minor

# 发布主要版本 (重大更新)
./scripts/release.sh major

# 发布指定版本
./scripts/release.sh 1.5.0

# 查看当前版本
./scripts/release.sh current
```

### 自动化流程

- 🏷️ **标签创建**: 自动创建Git标签和GitHub Release
- 📦 **Formula更新**: 自动更新Homebrew Formula的版本和SHA256
- 🧪 **CI测试**: 每次发布都经过完整的CI/CD测试
- 📋 **变更日志**: 基于Git提交自动生成发布说明

详细发布指南请参考 [RELEASE-GUIDE.md](docs/RELEASE-GUIDE.md)。

### 贡献指南

1. Fork 这个仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

### 测试要求

提交 PR 前请确保：
- [ ] 运行完整测试套件：`bash tests/run-all-tests.sh`
- [ ] 通过所有测试（45个测试）
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
- [跨平台设计文档](docs/CROSS-PLATFORM-DESIGN.md)

## 📊 版本历史

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
- 📚 跨平台设计文档
- 📚 平台功能矩阵文档
