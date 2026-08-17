# ADB QR Pair 使用指南

ADB QR Pair 通过二维码配对 Android 无线调试（adb pair）。在终端显示二维码，手机扫码后自动监听 mDNS（`_adb-tls-pairing._tcp`），发现设备后执行 `adb pair` 与自动 `connect`。

## 基本用法

```bash
adb-qr-pair
```

运行后终端显示二维码，在手机上依次进入：设置 → 开发者选项 → 无线调试 → 使用二维码配对设备，扫描二维码。脚本自动完成设备发现（mDNS）、`adb pair` 配对与 `adb connect` 连接。

## selftest：排查本机 mDNS

```bash
adb-qr-pair selftest
```

无需手机参与：脚本在本机注册一个临时 `_adb-tls-connect` 测试服务并验证能否 browse/解析。用于把两类故障切开：

- **selftest 失败** → 本机 mDNS 链路异常（常见原因：VPN/代理 utun 接口拦截组播），先解决本机问题；
- **selftest 通过但配对时发现不了手机** → 手机侧不广播（部分 ROM 仅在『无线调试』页面处于前台时广播）或 AP 隔离/访客网络。

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `ADB` | `$HOME/Library/Android/sdk/platform-tools/adb` | adb 路径，不存在时自动回退到 PATH 中的 adb |
| `PAIR_TIMEOUT` | `120` | mDNS 监听总时长（秒） |
| `PAIR_CMD_TIMEOUT` | `15` | 单次 `adb pair` 超时（秒） |
| `AUTO_CONNECT_WAIT` | `15` | 配对成功后轮询等待 adb 自动连接的总时长（秒），超时后优先读取 `adb mdns services`，再走 dns-sd/avahi 手动解析兜底 |
| `QR_SCALE` | `6` | 二维码缩放 |
| `DEBUG` | 关闭 | 置 `1` 时保留自动连接阶段的 mDNS 原始输出文件并在结束时打印路径（配对阶段输出走 FIFO 已被实时消费，不予保留） |
| `AVAHI_RESET` | 关闭 | 置 `1` 时 Linux 下先重启 avahi-daemon 清空 mDNS 缓存（需 sudo 免密） |

## 注意事项

- 手机与电脑需连接同一个 WiFi（访客网络 / AP 隔离会导致无法发现设备）。
- 扫码后手机需停留在"正在配对设备"页面，配对完成前不要退出。
- 配对端口与连接端口并不相同，扫码配对完成后连接端口还可能再次变化。macOS Bonjour 在旧记录尚未过期时，可能把新广播命名为同一 GUID 的 `(2)`、`(3)` 实例；脚本会识别这些后缀并优先尝试较新的端口。
- 配对成功后的自动连接依赖手机广播 `_adb-tls-connect`。**小米/HyperOS 等 ROM 仅在『无线调试』页面处于前台时广播**：若自动连接失败并提示"未广播"，保持手机停留在无线调试页面重跑脚本，或按页面显示的 `IP:端口` 手动执行 `adb connect`（该路径不依赖 mDNS，始终可用）。配对关系一次建立长期有效，之后无需再扫码。
- 若检测到 VPN/代理（utun）接口会给出提示，长期配对失败可临时关闭代理。
- 网络无外网时请先安装 `qrencode`（本 Formula 已自动安装），避免走在线二维码兜底。
