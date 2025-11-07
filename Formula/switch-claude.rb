class SwitchClaude < Formula
  desc "Claude Code model switching tool"
  homepage "https://github.com/yinzhenyu-su/homebrew-tools"
  url "https://github.com/yinzhenyu-su/homebrew-tools.git",
      tag:      "v1.0.0",
      revision: "3ae8e1372411f8f65a27d51717e40e4f87e98a47"
  license "MIT"

  depends_on "jq"

  def install
    bin.install "scripts/switch-claude.sh" => "switch-claude"
    bin.install_symlink "switch-claude" => "claude-switch"
    bin.install_symlink "switch-claude" => "sc"
  end

  def caveats
    <<~EOS
      Claude Code model switching tool installed successfully!

      Usage:
        switch-claude glm                    # Switch to GLM model
        switch-claude kimi                   # Switch to Kimi model
        switch-claude minimax                # Switch to Minimax model
        switch-claude current                # Display current configuration
        switch-claude clear                  # Clear configuration
        switch-claude help                   # Show help information

      Advanced usage:
        switch-claude glm --launch           # Switch and launch Claude Code
        switch-claude kimi --launch Hello    # Switch and send message

      Token management:
        switch-claude set-token <provider> <token>        # Store to file
        switch-claude set-keychain <provider> <token>     # Store to Keychain (recommended)
        switch-claude show-tokens                         # Show token status

      Alias commands:
        claude-switch  # Same as switch-claude
        sc            # Same as switch-claude

      Configuration file location: ~/.claude/settings.json
      Token configuration directory: ~/.config/switch-claude/

      Note: This tool requires Claude Code to be installed.
    EOS
  end

  test do
    system "#{bin}/switch-claude", "help"
    assert_path_exists bin/"switch-claude"
    assert_path_exists bin/"claude-switch"
    assert_path_exists bin/"sc"
  end
end
