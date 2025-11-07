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
│   ├── STRUCTURE.md            # 项目结构说明
│   └── CONVERSION-SUMMARY.md   # 转换总结文档
├── tests/                       # 测试文件
│   └── test-formula.sh         # Formula 测试脚本
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
# 推荐：使用 Keychain 存储（安全）
switch-claude set-keychain glm "your_glm_token"
switch-claude set-keychain kimi "your_kimi_token"
switch-claude set-keychain minimax "your_minimax_token"

# 或：存储到配置文件
switch-claude set-token glm "your_glm_token"
switch-claude set-token kimi "your_kimi_token"
switch-claude set-token minimax "your_minimax_token"

# 查看 token 状态
switch-claude show-tokens
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

- ✅ **安全的 Token 管理**: 支持 Keychain、配置文件、环境变量三种方式
- ✅ **多模型支持**: GLM、Kimi、Minimax
- ✅ **配置备份**: 每次切换前自动备份
- ✅ **快速启动**: 支持切换后直接启动 Claude Code
- ✅ **别名支持**: `switch-claude`、`claude-switch`、`sc`
- ✅ **详细帮助**: 完整的使用说明和示例

## 🔧 支持的模型

- **GLM**: 智谱 AI 的 GLM 系列模型（glm-4.5-air, glm-4.6）
- **Kimi**: 月之暗面的 Kimi 模型（kimi-k2-turbo-preview）
- **Minimax**: MiniMax 的模型（MiniMax-M2）

## 🔐 Token 优先级

脚本按以下优先级读取 token：

1. **macOS Keychain** (最安全，推荐)
2. **配置文件** (`~/.config/switch-claude/tokens.json`)
3. **环境变量** (`$GLM_TOKEN`, `$KIMI_TOKEN`, `$MINIMAX_TOKEN`)

## 📁 配置文件位置

- **Claude Code 配置**: `~/.claude/settings.json`
- **Token 配置**: `~/.config/switch-claude/tokens.json`
- **配置备份**: `~/.claude/settings.json.backup.YYYYMMDD_HHMMSS`

## 📋 依赖要求

- [jq](https://stedolan.github.io/jq/) - JSON 处理工具（会自动安装）
- [Claude Code](https://claude.ai/code) - 需要预先安装

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
