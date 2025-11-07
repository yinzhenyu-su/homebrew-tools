# Switch Claude - 项目结构说明

## 目录结构

```text
homebrew-tools/
├── README.md                    # 项目主文档
├── Formula/                     # Homebrew Formula 定义
│   └── switch-claude.rb        # switch-claude 包定义
├── scripts/                     # 主要脚本文件
│   └── switch-claude.sh        # Claude Code 模型切换脚本
├── docs/                        # 文档目录
│   ├── STRUCTURE.md            # 本文件 - 项目结构说明
│   └── CONVERSION-SUMMARY.md   # 转换总结文档
├── tests/                       # 测试文件
│   └── test-formula.sh         # Formula 测试脚本
└── .github/                     # GitHub 配置
    └── workflows/              # GitHub Actions 工作流
```

## 文件说明

### 核心文件

- **`scripts/switch-claude.sh`** - 主要的 Claude Code 模型切换脚本
- **`Formula/switch-claude.rb`** - Homebrew 包定义文件

### 文档文件

- **`README.md`** - 项目主文档，包含安装和使用说明
- **`docs/CONVERSION-SUMMARY.md`** - 从原始版本转换的总结
- **`docs/STRUCTURE.md`** - 项目结构说明（本文件）

### 测试文件

- **`tests/test-formula.sh`** - Homebrew Formula 的测试脚本

## 使用方式

1. **安装**: 通过 Homebrew 安装包
2. **配置**: 使用 token 管理命令设置 API tokens
3. **使用**: 通过 `switch-claude` 命令切换模型

## 开发指南

- 主要逻辑在 `scripts/switch-claude.sh` 中
- 修改后需要更新 `Formula/switch-claude.rb` 中的版本号
- 测试使用 `tests/test-formula.sh`
- 文档更新在 `docs/` 目录中
