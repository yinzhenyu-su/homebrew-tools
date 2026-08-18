

# Homebrew Tools

Claude Code 模型切换工具、adb 无线调试配对工具等的 Homebrew 包集合。

## 主要工具

### Switch Claude

一个强大的 Claude Code 模型切换脚本，支持在 GLM、Kimi、Minimax 等模型之间快速切换。Homebrew 安装后提供 `switch-claude`、`claude-switch` 与 `sc` 三个等价命令。

📖 详细用法见 [Switch Claude 使用指南](docs/switch-claude/usage.md)

### ADB QR Pair

通过二维码配对 Android 无线调试（adb pair）的脚本。在终端显示二维码，手机扫码后自动监听 mDNS（`_adb-tls-pairing._tcp`），发现设备后执行 `adb pair` 与自动 `connect`。

📖 详细用法见 [ADB QR Pair 使用指南](docs/adb-qr-pair/usage.md)

## 📦 安装

```bash
# 添加 tap
brew tap yinzhenyu-su/homebrew-tools

# 安装 switch-claude
brew install switch-claude

# 安装 adb-qr-pair
brew install adb-qr-pair
```

## 📋 依赖要求

- **switch-claude**: [jq](https://stedolan.github.io/jq/)（Formula 自动安装）、[Claude Code CLI](https://claude.ai/code)（需预先安装）、[gum](https://github.com/charmbracelet/gum)（可选）
- **adb-qr-pair**: [qrencode](https://fukuchi.org/works/qrencode/)（Formula 自动安装）、adb（Android SDK platform-tools，需自行安装）、avahi-utils（Linux 提供 `avahi-browse`，macOS 自带 `dns-sd`）、timeout/perl（超时控制）

## 🗑️ 卸载

```bash
brew uninstall switch-claude
brew uninstall adb-qr-pair
brew untap yinzhenyu-su/homebrew-tools
```

## 📄 许可证

MIT License

## 🔗 相关链接

- [开发与维护文档](docs/DEVELOPMENT.md)（测试、发布流程）
- [Claude Code 官方文档](https://docs.anthropic.com/claude/docs)
- [Homebrew 官方文档](https://docs.brew.sh/)
- [项目 Issues](https://github.com/yinzhenyu-su/homebrew-tools/issues)
- [测试套件文档](tests/switch-claude/README.md)
