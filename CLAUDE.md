# homebrew-tools

Claude Code 模型切换工具（switch-claude）的 Homebrew tap 仓库。

## 核心记忆层（不变约束）

### 内置 provider 一致性
新增内置 provider 时，`scripts/switch-claude.sh` 中以下 **4 处 `case` 必须同步更新**：
- `validate_provider()` — 内置校验白名单
- `remove_provider()` — 内置保护（禁止删除）
- `validate_provider_name()` — 名称冲突警告
- `list_providers()` — 显示"内置"标记

同时需在 `init_provider_config()` 的默认 provider.json 模板中追加配置。

### 测试必须隔离真实配置
所有测试脚本文件头已设置：
```bash
export SWITCH_CLAUDE_CONFIG_DIR="$(mktemp -d /tmp/switch-claude-test-XXXX)"
export SWITCH_CLAUDE_SETTINGS="$SWITCH_CLAUDE_CONFIG_DIR/settings.json"
```
**禁止在测试中直接读写 `~/.claude/settings.json` 或 `~/.config/switch-claude/`**。所有路径断言必须使用 `$SWITCH_CLAUDE_CONFIG_DIR` 和 `$SWITCH_CLAUDE_SETTINGS`。

### Formula 不可整体覆盖
`.github/workflows/release.yml` 中 `update-formula` job 用 `sed` **只替换 url / version / sha256 三行**。caveats、test block、dependencies 从已提交文件继承。**不可**在 workflow 中用 `cat >` 重写整个 Formula。

## 策略层（工作流编排）

### 发布流程
```
更新 caveats → Formula 版本号 → 提交 → git tag vX.Y.Z → git push origin vX.Y.Z
```
GitHub Actions 自动处理：Release 创建 → SHA 校验 → Formula 三行替换 → 自动 commit。

### 新增命令
```
help() 注册 → dispatch 分支 → 独立函数实现 → Formula caveats → 测试用例
```

## 执行层（可复用操作）

### 运行测试
```bash
bash tests/run-all-tests.sh          # 全部测试
bash tests/quick-test.sh             # 快速功能测试 (29 cases)
bash tests/test-errors.sh            # 错误处理测试 (24 cases)
bash tests/test-integration.sh       # 集成测试 (9 scenarios)
CI=true bash tests/quick-test.sh     # CI 模式（跳过交互）
```

### 项目结构
```
scripts/switch-claude.sh   # 主脚本 (~1710 行)
Formula/switch-claude.rb   # Homebrew Formula
tests/
  quick-test.sh            # 功能测试
  test-errors.sh           # 异常测试
  test-integration.sh      # 集成场景
.github/workflows/
  release.yml              # 发布工作流
  tests.yml                # CI 测试
```

### 调试快速参考
- `bash -n scripts/switch-claude.sh` — 语法检查
- `ruby -c Formula/switch-claude.rb` — Formula 语法检查
- 验证发布：`git archive --format=tar.gz --prefix=homebrew-tools-X.Y.Z/ vX.Y.Z | shasum -a 256`
