# 🎉 脚本已成功转换为 Homebrew Formula

你的 `switch-claude.sh` 脚本现在已经完全转换为一个标准的 Homebrew Formula！

## 📁 已创建的文件

- **`Formula/switch-claude.rb`** - Homebrew Formula 文件
- **`README.md`** - 项目主要说明文档
- **`test-formula.sh`** - 测试脚本（已通过测试 ✅）

## 🚀 快速开始

### 本地测试安装

```bash
brew install --build-from-source ./Formula/switch-claude.rb
```

### 安装后使用

```bash
switch-claude help          # 显示帮助
switch-claude glm           # 切换到 GLM
switch-claude kimi --launch # 切换到 Kimi 并启动
claude-switch minimax       # 使用别名命令
sc current                  # 使用短别名查看当前配置
```

## 🌟 主要特性

✅ **标准化安装**: 通过 `brew install` 安装
✅ **自动依赖**: 自动安装 `jq` 依赖
✅ **多个别名**: `switch-claude`, `claude-switch`, `sc`
✅ **系统集成**: 安装到标准 PATH 路径
✅ **完整测试**: 包含单元测试和集成测试
✅ **用户友好**: 安装后显示使用提示

## 📦 发布到 GitHub

要让其他用户能够安装，需要：

1. **推送到 GitHub**:

   ```bash
   git add .
   git commit -m "Add switch-claude homebrew formula"
   git push origin main
   ```

2. **用户安装方式**:

   ```bash
   brew tap yinzhenyu-su/homebrew
   brew install switch-claude
   ```

## 🔄 版本管理

当需要更新时：

1. 修改 `switch-claude.sh`
2. 更新 `Formula/switch-claude.rb` 中的版本号
3. 重新计算 SHA256 值
4. 提交到 GitHub

用户可通过 `brew upgrade switch-claude` 更新。

---

🎊 **恭喜！你的脚本现在是一个专业的 Homebrew 包了！**
