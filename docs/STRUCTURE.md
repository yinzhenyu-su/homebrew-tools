# Switch Claude - 项目结构说明

## 目录结构

```text
homebrew-tools/
├── README.md                    # 项目主文档
├── Formula/                     # Homebrew Formula 定义
│   └── switch-claude.rb        # switch-claude 包定义
├── scripts/                     # 主要脚本文件
│   └── switch-claude.sh        # Claude Code 模型切换脚本 (1513行)
├── docs/                        # 文档目录
│   └── STRUCTURE.md            # 本文件 - 项目结构说明
├── tests/                       # 测试文件目录
│   ├── README.md               # 测试套件文档
│   ├── run-all-tests.sh        # 测试套件主脚本 (477行)
│   ├── quick-test.sh           # 快速功能测试 (398行)
│   ├── test-errors.sh          # 错误处理测试 (458行)
│   ├── test-integration.sh     # 集成测试 (515行)
│   └── test-report.html        # 生成的HTML测试报告
└── .github/                     # GitHub 配置
    └── workflows/              # GitHub Actions 工作流
```

## 核心文件详解

### 主要脚本

- **`scripts/switch-claude.sh`** (1513行)
  - 支持跨平台（macOS/Linux）
  - Provider 配置管理（支持自定义 provider）
  - Token 存储：Keychain（macOS）、provider.json、环境变量
  - 动态帮助信息生成
  - 完整的错误处理和验证
  - 支持的模型：GLM、Kimi、Minimax

### 测试套件

- **`tests/run-all-tests.sh`** (477行)
  - 交互式测试菜单（5种运行模式）
  - 测试结果汇总和统计
  - HTML 测试报告生成
  - 跨平台自动适配（macOS/Linux）

- **`tests/quick-test.sh`** (398行) - 快速功能测试
  - 15个核心功能测试
  - 包括 help、provider 管理、token 管理、模型切换、Keychain 操作等
  - 支持 macOS Keychain 功能测试
  - 支持 Linux 环境（自动跳过 Keychain 相关测试）

- **`tests/test-errors.sh`** (458行) - 错误处理测试
  - 19个错误场景测试
  - 包括损坏 JSON、无效配置、权限问题、参数验证等
  - 智能跳过：macOS 系统自动跳过 jq 未安装测试
  - 跨平台错误处理验证

- **`tests/test-integration.sh`** (515行) - 集成测试
  - 7个完整用户场景（首次使用、自定义 Provider、Token 优先级、模型切换、Keychain 管理、配置恢复、批量操作）
  - 端到端工作流验证
  - Token 优先级测试（Keychain > Env > File > Prompt）
  - 真实场景模拟

- **`tests/test-report.html`** - HTML 测试报告
  - 自动生成的测试报告
  - 包含测试统计、通过率、详细结果
  - 支持浏览器查看

### 文档文件

- **`README.md`** - 项目主文档
  - 安装指南（Homebrew）
  - 完整使用说明和示例
  - 功能特性列表（跨平台、Token 管理、Provider 配置等）
  - 测试覆盖率信息（45个测试，100%通过率）
  - 发布管理流程

- **`docs/STRUCTURE.md`** - 本文件
  - 项目整体结构
  - 核心文件详解
  - 文件说明和开发指南

## 配置文件位置

### 用户配置
- `~/.claude/settings.json` - Claude Code 主配置
- `~/.config/switch-claude/provider.json` - Provider 配置
- `~/.config/switch-claude/tokens.json` - Token 配置（兼容旧版）
- `~/.claude/settings.json.backup.*` - 配置备份

### 项目配置
- `Formula/switch-claude.rb` - Homebrew 包定义
- `.github/workflows/` - GitHub Actions 工作流

## 架构特性

### 跨平台支持
- **macOS**: 原生 Keychain 支持，最佳安全性
- **Linux**: 建议使用 provider.json，或安装 GNOME Keyring
- **自动检测**: 脚本启动时自动检测平台和可用工具

### Token 管理优先级
1. **Keychain** (macOS) - 最安全
2. **环境变量** - 适合临时使用
3. **provider.json** - 推荐，管理灵活
4. **提示输入** - 最后保底

### Provider 系统
- **内置 Provider**: glm、kimi、minimax（不可删除）
- **自定义 Provider**: 用户可添加任意数量
- **验证机制**: 名称格式、JSON 完整性、必填字段检查

## 使用方式

### 安装
```bash
brew tap yinzhenyu-su/homebrew-tools
brew install switch-claude
```

### 基本使用
```bash
# 查看帮助（动态生成）
switch-claude help

# 初始化配置
switch-claude init-provider-config

# 列出可用 provider
switch-claude list-providers

# 设置 token
switch-claude set-token glm "your_token"
switch-claude set-keychain kimi "your_token"  # macOS 推荐

# 切换模型
switch-claude glm
switch-claude kimi
switch-claude minimax

# 查看当前配置
switch-claude current

# 添加自定义 provider
switch-claude add-provider MyAPI '{
  "ANTHROPIC_AUTH_TOKEN": "",
  "ANTHROPIC_BASE_URL": "https://api.custom.com/anthropic",
  "ANTHROPIC_MODEL": "custom-model"
}'
```

## 开发指南

### 代码结构
- **平台检测模块** (行 23-57): 自动检测操作系统和可用工具
- **公共函数** (行 59-89): 通用的验证和工具函数
- **Provider 配置管理** (行 151-537): 完整的 provider CRUD 操作
- **Token 管理** (行 417-770): 三种存储方式的统一接口
- **模型切换** (行 903-1017): 各模型特定的切换逻辑
- **动态帮助生成** (行 1122-1260): 根据平台生成不同帮助信息
- **命令可用性检查** (行 1262-1319): 智能提示平台不支持的功能

### 测试运行
```bash
# 运行所有测试（推荐）
bash tests/run-all-tests.sh

# 运行单个测试套件
bash tests/quick-test.sh          # 快速功能测试（15个测试）
bash tests/test-errors.sh         # 错误处理测试（19个测试）
bash tests/test-integration.sh    # 集成测试（11个测试）

# 查看 HTML 测试报告
open tests/test-report.html
```

### 本地开发
```bash
# 直接运行脚本
./scripts/switch-claude.sh help
./scripts/switch-claude.sh glm
./scripts/switch-claude.sh kimi

# 手动测试特定功能
bash -x tests/quick-test.sh        # 调试模式运行
```

## 依赖要求

### 必需
- **jq**: JSON 处理工具
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt install jq`

### 可选
- **gum**: 美化交互界面
  - macOS: `brew install gum`
  - 其他: https://github.com/charmbracelet/gum
- **GNOME Keyring** (Linux): 提供更安全的 token 存储
  - Ubuntu/Debian: `sudo apt install gnome-keyring libsecret-tools`

## 统计信息

- **总代码行数**: ~2950+ 行
  - 主脚本: 1513行
  - 测试脚本: 1848行（run-all-tests.sh: 477行 + quick-test.sh: 398行 + test-errors.sh: 458行 + test-integration.sh: 515行）
  - 文档: 约 600+ 行

- **测试覆盖**: 45个测试
  - 快速功能测试: 15个
  - 错误处理测试: 19个
  - 集成测试: 11个
  - 测试通过率: 100%
  - 跨平台支持: macOS/Linux 自动适配

- **支持平台**: macOS、Linux
- **功能模块**: 10+ 个主要模块
- **文档文件**: 3个（README.md、docs/STRUCTURE.md、tests/README.md）
- **配置文件**: 1个（Formula/switch-claude.rb）

## 许可证

MIT License
