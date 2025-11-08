class SwitchClaude < Formula
  desc "Claude Code 模型切换工具"
  homepage "https://github.com/yinzhenyu-su/homebrew-tools"
  url "https://github.com/yinzhenyu-su/homebrew-tools/archive/v2.0.0.tar.gz"
  version "2.0.0"
  sha256 "cbf066e1a02c9774fb82941f4a3a6765bd4ef29e796da5a7f0c79e2bab22519f"
  license "MIT"

  depends_on "jq"

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

      使用方法：
        switch-claude glm                    # 切换到 GLM 模型
        switch-claude kimi                   # 切换到 Kimi 模型
        switch-claude minimax                # 切换到 Minimax 模型
        switch-claude current                # 显示当前配置
        switch-claude clear                  # 清空配置
        switch-claude help                   # 显示帮助信息

      高级用法：
        switch-claude glm --launch           # 切换并启动 Claude Code
        switch-claude kimi --launch 你好     # 切换并发送消息

      Token 管理：
        switch-claude set-token <provider> <token>        # 存储到文件
        switch-claude set-keychain <provider> <token>     # 存储到 Keychain (推荐)
        switch-claude show-tokens                         # 显示 token 状态

      别名命令：
        claude-switch  # 等同于 switch-claude
        sc            # 等同于 switch-claude

      配置文件位置: ~/.claude/settings.json
      Token 配置目录: ~/.config/switch-claude/

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
