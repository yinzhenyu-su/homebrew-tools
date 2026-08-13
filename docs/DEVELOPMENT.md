# 开发与维护

本仓库的开发、测试与发布相关文档。

## 🧪 测试

### 运行测试套件

```bash
# 运行所有测试（自动发现 tests/*/ 子目录）
CI=true bash tests/run-all-tests.sh

# 运行特定测试
bash tests/switch-claude/test-errors.sh
bash tests/switch-claude/test-integration.sh
bash tests/adb-qr-pair/test-errors.sh
```

测试按工具分目录组织，`tests/run-all-tests.sh` 会自动发现所有 `tests/*/` 子目录中的测试脚本。

### 测试内容概览

- **switch-claude/test-errors.sh**: 构造非法 JSON、无效参数、缺失依赖等异常场景，验证错误提示是否准确 (26 cases)。
- **switch-claude/test-integration.sh**: 以端到端场景模拟真实使用流程（首次初始化、自定义 provider、Token 优先级、verify/restore 等）。
- **adb-qr-pair/test-errors.sh**: 以受限 PATH 隔离验证缺 adb、缺 timeout/perl、缺 mDNS 工具等场景的报错与退出码。
- **test-report.html**: `run-all-tests.sh` 结束后生成的可视化报告，包含统计概览和时间戳。

### 测试亮点

- ✅ 自动发现 `tests/*/` 子目录，新增工具只需创建新目录。
- ✅ 自动检测操作系统并在不支持的功能上回退或跳过。
- ✅ 对 token、配置文件和 Keychain 的读写进行了大量断言，覆盖 60+ 关键检查点。
- ✅ 所有脚本通过 `SWITCH_CLAUDE_CONFIG_DIR` / `SWITCH_CLAUDE_SETTINGS` 隔离临时目录，避免污染用户真实配置。

## 👨‍💻 本地开发

```bash
# 克隆仓库
git clone https://github.com/yinzhenyu-su/homebrew-tools.git
cd homebrew-tools

# 运行脚本
./scripts/switch-claude.sh help

# 运行完整测试套件
bash tests/run-all-tests.sh
```

## 贡献指南

1. Fork 这个仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

### 测试要求

提交 PR 前请确保：

- [ ] 运行完整测试套件：`CI=true bash tests/run-all-tests.sh`
- [ ] 确认各工具子目录下的测试全部通过
- [ ] 跨平台兼容性（macOS/Linux）
- [ ] 更新相关文档

## 扩展新工具

添加新的 Homebrew formula 项目时：

1. 在 `scripts/` 中放置主脚本
2. 在 `Formula/` 中创建对应的 `.rb` 文件
3. 在 `tests/` 中创建工具同名子目录，放入测试脚本
4. 发布时使用 `工具名-v版本号` 格式的 tag（如 `my-tool-v1.0.0`），release workflow 自动适配。例如 adb-qr-pair 的首个版本 tag 为 `adb-qr-pair-v1.0.0`。

## 发布流程

本项目通过 GitHub Actions 自动处理 Homebrew Formula 的版本更新。

**触发方式（二选一）：**

1. **自动触发** — 推送标签，支持两种格式：
   ```bash
   # 默认工具（switch-claude）：v版本号
   git tag v2.1.0
   git push origin v2.1.0

   # 其他工具：工具名-v版本号
   git tag my-tool-v1.0.0
   git push origin my-tool-v1.0.0

   # 例如发布 adb-qr-pair
   git tag adb-qr-pair-v1.0.0
   git push origin adb-qr-pair-v1.0.0
   ```

2. **手动触发** — 在 GitHub 仓库的 Actions 页面选择 `Release and Update Formula` 工作流，点击 `Run workflow` 并输入工具名和版本号。

**发布前检查清单：**

- [ ] 运行 `bash tests/run-all-tests.sh` 确认全部测试通过
- [ ] 更新 `Formula/switch-claude.rb` 中的 caveats 文本（如有新命令）
- [ ] 更新 README 与各工具 `usage.md`（如有内容变更）
- [ ] 确认 `Formula/` 下每个 `.rb` 文件的 caveats 与当前命令列表一致

**发布后自动完成：**

| 步骤 | 说明 |
|---|---|
| ① 创建 GitHub Release | 自动生成 changelog（基于 commit 历史） |
| ② 计算 SHA256 | 从 GitHub Archive 下载 tarball 并计算校验和 |
| ③ 更新 Formula | 只替换 `url`、`version`、`sha256` 三行，保留 caveats/test 内容 |
| ④ 提交并推送 | 自动 commit 到 `main` 分支，用户直接 `brew upgrade` 即可获取更新 |
