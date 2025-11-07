# 发布指南

本文档介绍如何发布和自动打包 `switch-claude` Homebrew Formula。

## 🚀 自动化发布流程

### 1. 前提条件

- 确保所有变更已提交到 `main` 分支
- 工作区干净（无未提交的变更）
- 已配置GitHub Personal Access Token（如需要）

### 2. 使用发布脚本

我们提供了一个自动化的发布脚本 `scripts/release.sh`，支持语义化版本管理：

```bash
# 发布补丁版本 (1.0.0 -> 1.0.1)
./scripts/release.sh patch

# 发布次要版本 (1.0.1 -> 1.1.0)
./scripts/release.sh minor

# 发布主要版本 (1.1.0 -> 2.0.0)
./scripts/release.sh major

# 发布指定版本
./scripts/release.sh 1.5.0

# 查看当前版本
./scripts/release.sh current

# 查看帮助
./scripts/release.sh help
```

### 3. 手动发布（GitHub Web界面）

如果需要通过GitHub Web界面手动触发发布：

1. 进入 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 选择 **Release and Update Formula** 工作流
4. 点击 **Run workflow**
5. 输入版本号（如 `1.2.0`）
6. 点击 **Run workflow** 确认

## 🔄 自动化流程详解

当创建新的Git标签（如 `v1.2.0`）时，会自动触发以下流程：

### 第一阶段：创建发布

1. **验证版本**：确认版本格式正确
2. **生成变更日志**：基于Git提交记录自动生成
3. **创建GitHub Release**：创建正式的GitHub发布页面

### 第二阶段：更新Formula

1. **下载源码**：从GitHub获取指定标签的源码包
2. **计算SHA256**：计算源码包的校验和
3. **更新Formula**：自动更新以下内容：
   - 版本号 (`version`)
   - 下载URL (`url`)
   - SHA256校验和 (`sha256`)
4. **测试Formula**：运行语法检查和安装测试
5. **提交更新**：自动创建提交并推送

### 第三阶段：通知完成

- 显示发布状态
- 提供安装命令
- 生成用户可用的安装说明

## 📋 发布前检查清单

在发布新版本之前，请确保：

- [ ] 所有功能正常工作
- [ ] 运行本地测试：`./tests/test-formula.sh`
- [ ] 更新了相关文档（如需要）
- [ ] 提交了所有变更
- [ ] 工作区干净
- [ ] 在正确的分支（通常是 `main`）

## 🧪 测试Formula

在发布前，建议进行本地测试：

```bash
# 运行完整测试套件
./tests/test-formula.sh

# 手动测试安装
brew install --build-from-source ./Formula/switch-claude.rb

# 测试功能
switch-claude help
switch-claude current

# 清理
brew uninstall switch-claude
```

## 🔧 故障排除

### 发布失败

如果自动发布流程失败：

1. **查看Actions日志**：在GitHub仓库的Actions页面查看详细错误信息
2. **检查权限**：确保GitHub Actions有足够的权限
3. **验证Formula语法**：运行 `brew audit --strict Formula/switch-claude.rb`
4. **重新触发**：修复问题后可以重新运行工作流

### 常见问题

**Q: SHA256不匹配**
A: 这通常是因为GitHub还未完成标签的源码打包。等待几分钟后重试。

**Q: Formula安装失败**
A: 检查依赖（如jq）是否正确配置，确认脚本路径正确。

**Q: 权限错误**
A: 确保GitHub Actions有write权限，检查GITHUB_TOKEN配置。

## 📦 用户安装流程

发布完成后，用户可以通过以下方式安装：

```bash
# 添加tap
brew tap yinzhenyu-su/homebrew-tools

# 安装工具
brew install switch-claude

# 验证安装
switch-claude help
```

## 🔄 版本管理策略

我们采用[语义化版本](https://semver.org/lang/zh-CN/)管理：

- **主版本号**：不兼容的API修改
- **次版本号**：向下兼容的功能性新增
- **修订号**：向下兼容的问题修正

### 版本规划

- `1.x.x`：当前稳定版本系列
- `2.x.x`：下一个主要版本（重大改进）

## 📝 发布注意事项

1. **发布时机**：建议在功能完整且测试充分后发布
2. **版本跳跃**：避免跳跃版本号，保持连续性
3. **文档更新**：重要变更需要更新README和文档
4. **向后兼容**：尽量保持向后兼容，重大变更提前通知

## 🤖 CI/CD工作流

项目包含以下GitHub Actions工作流：

- **tests.yml**：持续集成测试
- **publish.yml**：bottle构建和发布
- **release.yml**：版本发布和Formula更新

这些工作流确保每次发布都经过充分测试和验证。

