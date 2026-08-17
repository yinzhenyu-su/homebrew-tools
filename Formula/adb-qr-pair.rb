class AdbQrPair < Formula
  desc "通过二维码配对 Android 无线调试 (adb pair)"
  homepage "https://github.com/yinzhenyu-su/homebrew-tools"
  url "https://github.com/yinzhenyu-su/homebrew-tools/archive/adb-qr-pair-v1.1.0.tar.gz"
  version "1.1.0"
  sha256 "811a7e9857481fa6f96944515cd8ac9480f9c2f02bfca8eb6ff66accb7e87a6e"

  depends_on "qrencode"

  def install
    bin.install "scripts/adb-qr-pair.sh" => "adb-qr-pair"
  end

  def caveats
    <<~EOS
      adb-qr-pair 通过二维码配对 Android 无线调试 (adb pair)。

      依赖说明：
        - qrencode: 已随本 Formula 自动安装
        - adb: 需要 Android SDK platform-tools 提供的 adb
            macOS: brew install --cask android-platform-tools
            Linux: 安装 android-tools-adb (apt) / android-tools (dnf/yum)
          脚本默认查找 $HOME/Library/Android/sdk/platform-tools/adb,
          不存在时自动回退到 PATH 中的 adb; 也可用环境变量 ADB 指定:
            ADB=/path/to/adb adb-qr-pair
        - mDNS 发现工具: macOS 自带 dns-sd; Linux 需安装 avahi-utils
            Ubuntu/Debian: sudo apt install avahi-utils
            Fedora: sudo dnf install avahi-tools
            Arch: sudo pacman -S avahi
        - 超时控制: macOS 自带 perl; Linux 使用 coreutils 的 timeout

      使用方法：
        adb-qr-pair           配对并自动连接
        adb-qr-pair selftest  无需手机, 验证本机 mDNS 收发链路 (排查配对时"发现不了手机")

      环境变量：
        ADB               adb 路径 (默认 $HOME/Library/Android/sdk/platform-tools/adb)
        PAIR_TIMEOUT      mDNS 监听总时长, 秒 (默认 120)
        PAIR_CMD_TIMEOUT  单次 adb pair 超时, 秒 (默认 15)
        AUTO_CONNECT_WAIT 配对成功后轮询等待 adb 自动连接的总时长, 秒 (默认 15)
        QR_SCALE          二维码缩放 (默认 6)
        DEBUG=1           保留自动连接阶段的 mDNS 原始输出并打印路径
        AVAHI_RESET=1     Linux 下先重启 avahi-daemon 清空 mDNS 缓存 (需 sudo 免密)

      注意：手机与电脑需连接同一 WiFi; 扫码后请停留在配对页面直到配对完成。
    EOS
  end

  test do
    assert_predicate bin/"adb-qr-pair", :executable?

    # 在无 adb 的干净环境 (PATH 受限, 规避真实 adb/网络/二维码依赖),
    # 应稳定报 "找不到 adb" 并以退出码 1 结束
    output = shell_output("PATH=/nonexistent ADB=/nonexistent/adb /bin/sh #{bin}/adb-qr-pair 2>&1", 1)
    assert_match(/找不到 adb/, output.force_encoding("UTF-8"))
  end
end
