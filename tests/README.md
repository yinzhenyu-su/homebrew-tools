# Switch Claude 测试套件

本目录包含 switch-claude.sh 脚本的完整测试套件，支持跨平台测试（macOS/Linux/Windows）。

## 📁 文件结构

```
tests/
├── README.md                  # 本文件
├── run-all-tests.sh           # 运行所有测试的主脚本
├── quick-test.sh              # 快速功能测试 (macOS/Linux)
├── test-errors.sh             # 错误处理测试
├── test-integration.sh        # 集成测试
└── test-report.html           # 生成的HTML测试报告
```

## 🚀 快速开始

### 运行所有测试

```bash
# 方式 1: 使用主脚本（推荐）
bash tests/run-all-tests.sh

# 方式 2: 直接运行单个测试套件
bash tests/quick-test.sh        # 快速测试 (macOS/Linux)
bash tests/test-errors.sh       # 错误测试
bash tests/test-integration.sh  # 集成测试
```

### 交互式菜单

运行 `run-all-tests.sh` 会显示交互式菜单：

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          Switch Claude 测试套件                              ║
║                                                              ║
║  1. 运行所有测试 (推荐)                                       ║
║  2. 仅运行快速测试                                           ║
║  3. 仅运行错误测试                                           ║
║  4. 仅运行集成测试                                           ║
║  5. 自定义选择                                               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

### ⚠️ 跨平台说明

**所有平台用户**：
```bash
bash tests/quick-test.sh
```

✅ **支持**: 脚本会自动检测操作系统并适配测试：
- **macOS**: 完整测试，包括 Keychain 功能
- **Linux/Ubuntu**: 自动跳过 Keychain 相关测试，使用 `set-token` 命令

### 运行特定测试

```bash
# 快速测试（适用于所有平台）
bash tests/quick-test.sh

# 仅运行错误处理测试
bash tests/test-errors.sh

# 仅运行集成测试（测试完整工作流）
bash tests/test-integration.sh
```

## 📊 测试内容

### 1. 快速功能测试 (quick-test.sh - 跨平台)

**测试范围:**
- ✅ help 命令
- ✅ 依赖检查（jq）
- ✅ provider.json 自动创建
- ✅ list-providers 命令
- ✅ show-provider-config 命令
- ✅ add-provider 命令
- ✅ set-token 命令
- ✅ remove-provider 命令
- ✅ 内置 provider 保护
- ✅ set-keychain 命令 ⭐ (macOS Keychain, Linux 自动跳过)
- ✅ clear-keychain 命令 ⭐ (macOS Keychain, Linux 自动跳过)
- ✅ clear-all-keychains 命令 ⭐ (macOS Keychain, Linux 自动跳过)
- ✅ 模型切换（GLM、Kimi、Minimax）
- ✅ current 命令
- ✅ 输入验证
- ✅ 跨平台功能检测
- ✅ 动态帮助信息生成
- ✅ 命令可用性检查

**运行时间:** < 30 秒

**说明:**
- **macOS**: 完整测试，包括 Keychain 功能
- **Linux/Ubuntu**: 自动跳过 Keychain 相关测试，使用 `set-token` 命令

### 2. 错误处理测试 (test-errors.sh)

**测试范围:**
- ✅ 损坏的 JSON 文件检测
- ✅ 空文件/空对象检测
- ✅ 无效 provider 名称（特殊字符、超长、空字符串）
- ✅ 无效 JSON 配置（语法错误、缺少字段）
- ✅ 无效 BASE_URL 检测
- ✅ 尝试删除内置 provider 保护
- ✅ 不存在的 provider 错误
- ✅ 空 token 验证
- ✅ 不完整的参数检查
- ✅ jq 未安装检测（macOS 自动跳过）
- ✅ 无效配置文件权限
- ✅ 无效命令处理
- ✅ 循环依赖防护
- ✅ 重复 provider 处理
- ✅ 极长 token 处理
- ✅ 跨平台错误处理

**运行时间:** < 2 分钟

**特色功能:**
- 智能跳过：macOS 系统自动跳过 jq 未安装测试（避免权限问题）
- 跨平台：自动检测操作系统，提供平台特定的错误信息

### 3. 集成测试 (test-integration.sh)

**测试场景:**
- ✅ 场景 1: 首次使用流程（自动创建配置）
- ✅ 场景 2: 自定义 Provider 完整流程（添加、使用、删除）
- ✅ 场景 3: Token 优先级测试（Keychain > Env > File > Prompt）
- ✅ 场景 4: 完整模型切换工作流（GLM、Kimi、Minimax）
- ✅ 场景 5: Keychain 管理功能（存储、读取、清除）
- ✅ 场景 6: 配置恢复场景
- ✅ 场景 7: 批量操作场景

**运行时间:** < 2 分钟

**特色功能:**
- 完整工作流：测试从首次使用到日常使用的完整流程
- Token 优先级：验证 Keychain > 环境变量 > provider.json > 提示输入的优先级
- 真实场景：模拟实际用户使用场景

## 📈 跨平台测试

### 平台检测功能

测试套件包含完整的跨平台检测功能：

```bash
# 查看系统信息
switch-claude --system-info

# 输出示例：
# 系统信息:
#   操作系统: macos
#   jq: ✓ 已安装
#   Keychain: ✓ 可用
#   secret-tool: ✗ 不可用
#   gum: ✓ 已安装
```

### 命令可用性检查

```bash
# 检查命令在当前系统是否可用
is_command_available "set-keychain"  # macOS: true, Linux: false
is_command_available "set-secret"    # Linux (有GNOME Keyring): true
is_command_available "set-token"     # 所有系统: true
```

### 动态帮助信息

帮助信息会根据操作系统动态生成：

**macOS**:
- 显示 Keychain 相关命令
- 推荐使用 Keychain 存储

**Linux**:
- 显示文件存储命令
- 可选安装 GNOME Keyring

## 📝 测试报告

运行测试后会生成以下内容：

1. **控制台输出** - 实时显示测试进度和结果
2. **HTML 报告** - `tests/test-report.html` - 可在浏览器中查看详细测试结果

### 测试统计

```
总测试套件: 3
总测试数: 45
通过: 45
失败: 0
通过率: 100%
```

### 查看报告

```bash
# 生成并打开报告
open tests/test-report.html

# 或使用浏览器直接打开
open tests/test-report.html
```

## 🔧 测试环境准备

### 前置要求

1. **安装 jq**
   ```bash
   # macOS
   brew install jq

   # Ubuntu/Debian
   sudo apt install jq
   ```

2. **确保脚本可执行**
   ```bash
   chmod +x scripts/switch-claude.sh
   ```

3. **Keychain 访问权限（仅 macOS）**
   - macOS 用户：需要访问系统 Keychain
   - Ubuntu 用户：**跳过此步**，`quick-test.sh` 会自动处理

4. **可选：安装 gum（美化的交互界面）**
   ```bash
   # macOS
   brew install gum

   # 其他系统：https://github.com/charmbracelet/gum
   ```

### 清理测试环境

测试脚本会自动清理测试数据，但也可以手动清理：

```bash
# 清理配置
rm -rf ~/.config/switch-claude
rm -f ~/.claude/settings.json.backup.*

# 清理 Keychain
security delete-generic-password -a "$USER" -s "switch-claude-glm" >/dev/null 2>&1 || true
security delete-generic-password -a "$USER" -s "switch-claude-kimi" >/dev/null 2>&1 || true
security delete-generic-password -a "$USER" -s "switch-claude-minimax" >/dev/null 2>&1 || true
```

## 📋 测试数据

### 测试用 Provider 配置

```json
{
  "ANTHROPIC_AUTH_TOKEN": "",
  "ANTHROPIC_BASE_URL": "https://api.test.com/anthropic",
  "ANTHROPIC_MODEL": "test-model"
}
```

### 测试用 Token

```bash
TEST_TOKENS=(
    "short"
    "medium-length-token-123"
    "very-long-token-with-many-characters"
    $'token\nwith\nnewlines'
    'token"with"quotes'
    $'A%.0s' {1..10240}  # 10KB token
)
```

## 🐛 调试测试

如果测试失败，可以通过以下方式调试：

### 1. 查看详细输出

```bash
# 运行单个测试并查看详细输出
bash -x tests/quick-test.sh
```

### 2. 检查测试数据

```bash
# 查看 provider.json
cat ~/.config/switch-claude/provider.json

# 查看 Keychain
security find-generic-password -a "$USER" -s "switch-claude-glm" -w
```

### 3. 逐步测试

```bash
# 手动运行单个命令测试
./scripts/switch-claude.sh list-providers
./scripts/switch-claude.sh show-provider-config
```

### 4. 跨平台测试

```bash
# 测试平台检测
source scripts/platform-detector.sh
echo "OS_TYPE: $OS_TYPE"
echo "HAS_KEYCHAIN: $HAS_KEYCHAIN"

# 测试命令可用性
source scripts/platform-detector.sh
is_command_available "set-keychain"  # macOS: true, Linux: false
```

## 📊 覆盖率目标

- **函数覆盖率:** 95%+
- **分支覆盖率:** 90%+
- **代码行覆盖率:** 85%+
- **跨平台覆盖率:** 100%（macOS/Linux/Windows）

## ⚠️ 注意事项

1. **测试会修改配置文件** - 测试会自动清理，但请确保没有重要的配置数据
2. **需要 Keychain 权限** - 部分测试需要访问 macOS Keychain
3. **需要 jq** - 所有测试都依赖 jq 工具
4. **测试顺序** - 测试之间有依赖关系，请按顺序运行
5. **跨平台兼容** - 测试套件会自动适配不同操作系统

## 🚀 持续集成

在 CI/CD 中运行测试：

```bash
# GitHub Actions 示例
- name: Run Tests
  run: |
    bash tests/quick-test.sh
    bash tests/test-errors.sh
    bash tests/test-integration.sh

# 跨平台测试
- name: Test on macOS
  run: bash tests/quick-test.sh
- name: Test on Linux
  run: bash tests/quick-test.sh
```

## 📚 更多资源

- [项目文档](../README.md)
- [脚本源码](../scripts/switch-claude.sh)
- [项目结构说明](../docs/STRUCTURE.md)

## 🔄 测试套件更新日志

### v1.0.3 (2025-11-09)

**新增功能:**
- ✅ 集成测试结果汇总功能
- ✅ macOS jq 测试智能跳过
- ✅ 跨平台功能检测模块
- ✅ 动态帮助信息生成
- ✅ 命令可用性检查
- ✅ HTML 测试报告生成
- ✅ 集成测试场景扩充（7个完整场景）
- ✅ Token 优先级完整验证
- ✅ Keychain 管理测试

**修复问题:**
- ✅ 修复测试计数错误（通过数 > 总测试数）
- ✅ 修复 sed 跨平台兼容性问题
- ✅ 修复集成测试中 token 脱敏检查
- ✅ 修复测试输出中的特殊字符问题
- ✅ 修复 macOS Keychain 输出噪音
- ✅ 修复测试界面重复显示问题

**改进:**
- 🔧 测试套件支持 5 种运行模式
- 🔧 跨平台测试（macOS/Linux 自动适配）
- 🔧 测试结果实时汇总和统计
- 🔧 详细的测试进度显示
- 🔧 智能跳过平台不支持的测试

---

**版本:** 1.0.3
**最后更新:** 2025-11-09
