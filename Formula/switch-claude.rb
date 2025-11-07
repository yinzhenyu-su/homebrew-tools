class SwitchClaude < Formula
  desc "Claude Code 模型切换工具"
  homepage "https://github.com/yinzhenyu-su/homebrew-tools"
  url "https://github.com/yinzhenyu-su/homebrew-tools/archive/v1.0.1.tar.gz"
  version "1.0.1"
  sha256 "3d008614cb4f1143ef586b5cb60c72ac987608e0e606166fee7aace0f892d001"
  license "MIT"

  # 必需依赖
  depends_on "jq"

  # 可选依赖（提供更美观的交互界面）
  depends_on "gum"

  def install
    # 安装脚本到 bin 目录
    bin.install "scripts/switch-claude.sh" => "switch-claude"

    # 创建符号链接以支持常用别名
    bin.install_symlink "switch-claude" => "claude-switch"
    bin.install_symlink "switch-claude" => "sc"
  end

  def caveats
    <<~EOS
      Claude Code 模型切换工具已安装成功！
      运行 `switch-claude help` 查看使用说明

      注意：此工具需要您已经安装了 Claude Code。
    EOS
  end

  test do
    # 测试帮助命令
    system "#{bin}/switch-claude", "help"

    # 测试依赖检查
    assert_predicate bin/"switch-claude", :exist?
    assert_predicate bin/"claude-switch", :exist?
    assert_predicate bin/"sc", :exist?
  end
end
