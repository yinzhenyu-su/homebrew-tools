# ADB QR Pair 使用指南

ADB QR Pair 通过二维码配对 Android 无线调试（adb pair）。在终端显示二维码，手机扫码后自动监听 mDNS（`_adb-tls-pairing._tcp`），发现设备后执行 `adb pair` 与自动 `connect`。

## 基本用法

```bash
adb-qr-pair
```

运行后终端显示二维码，在手机上依次进入：设置 → 开发者选项 → 无线调试 → 使用二维码配对设备，扫描二维码。脚本自动完成设备发现（mDNS）、`adb pair` 配对与 `adb connect` 连接。

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `ADB` | `$HOME/Library/Android/sdk/platform-tools/adb` | adb 路径，不存在时自动回退到 PATH 中的 adb |
| `PAIR_TIMEOUT` | `120` | mDNS 监听总时长（秒） |
| `PAIR_CMD_TIMEOUT` | `15` | 单次 `adb pair` 超时（秒） |
| `QR_SCALE` | `6` | 二维码缩放 |
| `AVAHI_RESET` | 关闭 | 置 `1` 时 Linux 下先重启 avahi-daemon 清空 mDNS 缓存（需 sudo 免密） |

## 注意事项

- 手机与电脑需连接同一个 WiFi（访客网络 / AP 隔离会导致无法发现设备）。
- 扫码后手机需停留在"正在配对设备"页面，配对完成前不要退出。
- 若检测到 VPN/代理（utun）接口会给出提示，长期配对失败可临时关闭代理。
- 网络无外网时请先安装 `qrencode`（本 Formula 已自动安装），避免走在线二维码兜底。
