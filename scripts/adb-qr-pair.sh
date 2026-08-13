#!/usr/bin/env sh
#
# adb-qr-pair.sh - 通过二维码配对 Android 无线调试 (adb pair)
#
# 对应 etng/adb-auto-pair (Go) 的 shell 实现, 流程:
#   1. 随机生成 24 位服务 ID (S) 和 6 位配对码 (P)
#   2. 生成二维码 WIFI:T:ADB;S:<id>;P:<psk>;; 并在终端显示
#      -> 手机: 设置 -> 开发者选项 -> 无线调试 -> 使用二维码配对设备, 扫描二维码
#   3. 手机扫码后通过 mDNS 广播服务 _adb-tls-pairing._tcp (实例名 = S)
#   4. 本机用 dns-sd -L (macOS) / avahi-browse (Linux) 发现该服务, 解析出 host:port
#   5. 执行 adb pair host:port psk, 再 adb devices -l
#
# 依赖: qrencode (brew install qrencode), dns-sd (macOS 自带) 或 avahi-utils (Linux)
# 超时控制: Linux 用 coreutils 的 timeout (无需 perl); macOS 没有 timeout, 用自带 perl
# 用法: ./scripts/adb-qr-pair.sh
# 环境变量: ADB, PAIR_TIMEOUT(秒, 默认 120, mDNS 监听总时长), PAIR_CMD_TIMEOUT(秒, 默认 15,
#          单次 adb pair 超时; adb pair 在配对握手未完成时会无限挂起, 必须兜底),
#          QR_SCALE(默认 6)

set -eu

ADB=${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}
# 优先用 SDK platform-tools 的 adb (版本最新, 配对协议兼容性最好; 与 etng/adb-auto-pair 一致),
# 该路径不存在时回退到 PATH 里的 adb (仓库其他脚本用 ADB=${ADB:-adb} 直接从 PATH 取).
# 不用 which: 非 POSIX 标准, 且可能命中 Homebrew 等处的旧版 adb, 配对不兼容.
if [ ! -x "$ADB" ]; then
  ADB=$(command -v adb 2>/dev/null || true)
fi
DNS_DOMAIN="_adb-tls-pairing._tcp"
PAIR_TIMEOUT=${PAIR_TIMEOUT:-120}
PAIR_CMD_TIMEOUT=${PAIR_CMD_TIMEOUT:-15}
QR_SCALE=${QR_SCALE:-6}

die() {
  echo "错误: $*" >&2
  exit 1
}

[ -x "$ADB" ] || die "找不到 adb (可通过环境变量 ADB 指定, 或安装 Android SDK platform-tools)"

# ---- 前置依赖检查 (全部通过后才显示二维码, 避免扫了码才发现缺依赖) ----
# 超时控制: Linux 用 coreutils 的 timeout; macOS 没有 timeout, 用自带 perl
command -v timeout >/dev/null 2>&1 || command -v perl >/dev/null 2>&1 || \
  die "未找到 timeout 或 perl (超时控制需要其中之一; Linux 装 coreutils, macOS 自带 perl)"
# mDNS 发现: macOS 自带 dns-sd; Linux 需要 avahi-utils 的 avahi-browse
command -v dns-sd >/dev/null 2>&1 || command -v avahi-browse >/dev/null 2>&1 || \
  die "未找到 mDNS 发现工具 (macOS 自带 dns-sd; Linux 请安装 avahi-utils: apt install avahi-utils / yum install avahi-tools / pacman -S avahi)"

# 生成 n 位随机字母 (与 Go 实现一致; 手机端只要求 S/P 非空)
rand_letters() {
  LC_ALL=C tr -dc 'a-zA-Z' < /dev/urandom | head -c "$1"
}

SVC_ID=$(rand_letters 24)
PSK=$(rand_letters 6)
QR_CONTENT="WIFI:T:ADB;S:${SVC_ID};P:${PSK};;"

echo "服务 ID : $SVC_ID"
echo "配对码  : $PSK"
echo

# ---- 1. 在终端显示二维码 ----
if command -v qrencode >/dev/null 2>&1; then
  qrencode -s "$QR_SCALE" -m 2 -t ANSIUTF8 "$QR_CONTENT"
else
  echo "警告: 未安装 qrencode, 改用在线服务生成二维码 (内容会发送给第三方)" >&2
  curl -fsS "https://qrenco.de/$QR_CONTENT" || die "二维码生成失败 (建议先安装 qrencode)"
fi

echo
echo "在手机上操作: 设置 -> 开发者选项 -> 无线调试 -> 使用二维码配对设备, 扫描上方二维码"
echo "注意: 扫码后手机停在\"正在配对设备\"页面, 配对成功前请不要退出"
echo "注意: 请确认手机与本机连接同一个 WiFi (访客网络/AP 隔离会导致无法发现设备)"
echo "正在监听 mDNS (${DNS_DOMAIN}), 最长等待 ${PAIR_TIMEOUT}s ..."
if ifconfig 2>/dev/null | grep -q '^utun'; then
  echo "提示: 检测到 VPN/代理 (utun) 接口, 若一直配对失败可尝试临时关闭代理" >&2
fi

# ---- 2. mDNS 发现 + 配对 ----
# mDNS 工具输出写入 FIFO, 主循环逐行读取; 配对成功立即 kill 后台进程退出,
# 不依赖管道收尾 (否则要等超时才会退出).
# dns-sd -L (macOS) 输出示例:
#   12:34:56.789  <id>._adb-tls-pairing._tcp.local. can be reached at <host>:<port> (interface 1)
# avahi-browse -r (Linux) 输出示例:
#   = eth0 IPv4 xxxxxxxxxxxx                       _adb-tls-pairing._tcp    local
#      hostname = [Android.local]
#      address  = [192.168.1.5]
#      port     = [37571]

# adb pair 失败时客户端只显示 "protocol fault (couldn't read status message)",
# 真实原因在 adb server 日志里; 打印日志尾部帮助定位
print_adb_server_log_tail() {
  _log=$("$ADB" server-status 2>/dev/null | sed -n 's/^log_absolute_path: "\(.*\)"/\1/p' | head -1)
  if [ -z "$_log" ] || [ ! -f "$_log" ]; then
    _log="$HOME/.android/adb.log"
  fi
  if [ -z "$_log" ] || [ ! -f "$_log" ]; then
    _log="${TMPDIR:-/tmp}/adb.log"
  fi
  if [ -f "$_log" ]; then
    _tail=$(tail -5 "$_log" 2>/dev/null)
    if [ -n "$_tail" ]; then
      echo "--- adb server 日志尾部 (真实失败原因) ---" >&2
      printf '%s\n' "$_tail" | sed 's/^/  /' >&2
    fi
  fi
}

# 带超时运行命令; 返回子进程退出码, 超时返回 124 (两种实现一致).
# Linux 优先用 coreutils 的 timeout (无需 perl); macOS 没有 timeout, 用自带 perl 实现.
# 必须给 adb pair 兜底超时: TCP 连接建立但 TLS 握手未完成时 adb pair 会无限挂起,
# 此时手机会一直停在"正在配对设备"页面 (脚本和手机一起卡死).
run_with_timeout() {
  _tmo=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 2 "$_tmo" "$@"
  else
    perl -e '
      $timeout = shift @ARGV;
      $pid = fork();
      exit 127 if !defined $pid;
      if (!$pid) { exec @ARGV; exit 127; }
      $SIG{ALRM} = sub { kill "KILL", $pid; exit 124 };
      alarm $timeout;
      waitpid($pid, 0);
      $rc = $?;
      exit($rc & 127 ? 128 | ($rc & 127) : $rc >> 8);
    ' "$_tmo" "$@"
  fi
}

# 后台运行带超时的 mDNS 工具 (直接后台执行, 保证外层 kill $discover_pid 能终止它;
# 不能包成普通函数再后台调用, 否则 discover_pid 是子 shell 的 PID, kill 不到
# timeout/perl, FIFO 写端不关闭, 主循环 read 会一直卡住).
start_discovery() {
  if command -v timeout >/dev/null 2>&1; then
    timeout -k 2 "$PAIR_TIMEOUT" "$@" >"$fifo" 2>&1 &
  else
    perl -e '
      $timeout = shift @ARGV;
      $pid = fork();
      exit 127 if !defined $pid;
      if (!$pid) { exec @ARGV; exit 127; }
      $SIG{TERM} = $SIG{ALRM} = sub { kill "KILL", $pid; exit 124 };
      alarm $timeout;
      waitpid($pid, 0);
      exit 0;
    ' "$PAIR_TIMEOUT" "$@" >"$fifo" 2>&1 &
  fi
}

# 配对成功后自动连接: 先等 adb 自带 mDNS 自动连接 (_adb-tls-connect) 完成;
# 未生效时 (容器/VM 等组播受限环境 adb 的 mDNS 不可用), 用 avahi-browse 解析
# _adb-tls-connect 手动 connect 兜底, 失败则延时重试 (配对刚完成时手机的
# connect 监听器可能还没就绪). $1 = guid (adb-xxxx 实例名, 来自配对输出,
# 用于过滤出刚配对的那台手机; 为空则取第一个可解析实例)
auto_connect() {
  _guid=${1:-}
  sleep 2   # 等 adb 自动 connect (mDNS _adb-tls-connect) 完成
  if "$ADB" devices | grep -qE '[[:space:]]device([[:space:]]|$)'; then
    "$ADB" devices -l || true
    return 0
  fi
  if ! command -v avahi-browse >/dev/null 2>&1; then
    echo "提示: adb 自动连接未生效, 请稍后手动执行: $ADB connect <手机ip>:<无线调试端口>" >&2
    "$ADB" devices -l || true
    return 0
  fi
  echo "adb 自带 mDNS 自动连接未生效, 用 avahi 解析 _adb-tls-connect 手动连接..." >&2
  _tmp=$(mktemp)
  _epsf=$(mktemp)
  _attempt=1
  while [ "$_attempt" -le 3 ]; do
    # 每次重新解析, 拿到手机最新广播的无线调试端口 (配对后端口可能变更);
    # 注意: 带引号的 case 模式不能放进 $(...) (bash 3.2 解析 bug), 这里用临时文件收集
    run_with_timeout 4 avahi-browse -r _adb-tls-connect._tcp >"$_tmp" 2>&1 || true
    _host=
    _port=
    _match=0
    while IFS= read -r _l; do
      case "$_l" in
        "+ "*|"- "*|"= "*)        # 服务事件行: 记录当前实例名, 按 guid 过滤
          set -- $_l
          if [ -n "$_guid" ]; then
            [ "$4" = "$_guid" ] && _match=1 || _match=0
          else
            _match=1
          fi
          ;;
        *"address = ["*)
          [ "$_match" = "1" ] && { _host=${_l##*"address = ["}; _host=${_host%%]*}; }
          ;;
        *"port = ["*)
          if [ "$_match" = "1" ] && [ -n "$_host" ]; then
            _port=${_l##*"port = ["}; _port=${_port%%]*}
            [ -n "$_port" ] && echo "$_host:$_port"
          fi
          ;;
      esac
    done <"$_tmp" >"$_epsf"
    _eps=$(sort -u "$_epsf")
    if [ -n "$_eps" ]; then
      for _ep in $_eps; do
        echo "\$ $ADB connect $_ep"
        if "$ADB" connect "$_ep" 2>&1 | grep -q "connected to"; then
          rm -f "$_tmp" "$_epsf"
          "$ADB" devices -l || true
          return 0
        fi
      done
    else
      echo "未解析到 _adb-tls-connect (第 $_attempt 次)" >&2
    fi
    [ "$_attempt" -lt 3 ] && { echo "手机 connect 监听器可能未就绪, ${_attempt} 次后重试..." >&2; sleep 3; }
    _attempt=$((_attempt + 1))
  done
  rm -f "$_tmp" "$_epsf"
  echo "自动连接失败, 请稍后手动执行: $ADB connect <手机ip>:<无线调试端口>" >&2
  "$ADB" devices -l || true
}

# 尝试用 adb 配对, 成功返回 0
# $1=addr $2=host $3=port
try_pair() {
  echo "发现设备: $2:$3"
  echo "\$ $ADB pair $1 $PSK"
  last_host=$2
  rc=0
  # 捕获输出: 部分 adb (Linux 发行版自带常见) 客户端误报
  # "protocol fault (couldn't read status message)" (误导性, 配对实际在手机端完成),
  # 捕获后不显示该行; 配对结果由手机端决定, 脚本保持监听等待自动连接/重试
  pair_out=$(run_with_timeout "$PAIR_CMD_TIMEOUT" "$ADB" pair "$1" "$PSK" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '%s\n' "$pair_out"
    echo "配对成功!"
    _guid=$(printf '%s\n' "$pair_out" | sed -n 's/.*guid=\([^]]*\).*/\1/p')
    auto_connect "${_guid:-}"
    return 0
  fi
  if [ "$rc" -eq 124 ]; then
    echo "adb pair 超时 (${PAIR_CMD_TIMEOUT}s): TCP 已连接但握手未完成, 手机仍停在配对页; 常见原因: WiFi 网络异常/AP 隔离、代理/VPN 拦截、手机端未就绪. 继续监听重试..." >&2
  else
    echo "adb pair 失败 (退出码 $rc), 继续监听 (设备可能更换了端口)..." >&2
  fi
  print_adb_server_log_tail
  return 1
}

fifo_dir=$(mktemp -d)
fifo="$fifo_dir/out"
mkfifo "$fifo" || die "创建 FIFO 失败"

# 后台运行 mDNS 工具, PAIR_TIMEOUT 秒后自动终止 (优先 GNU timeout, 回退 perl).
# Linux 可选: AVAHI_RESET=1 时先重启 avahi-daemon 清空 mDNS 缓存. 长运行后缓存会
# 堆满解析超时的幽灵实例 (旧配对会话/其他设备广播), 拖慢甚至阻塞新实例的解析;
# 实测重启后配对发现明显更快. 需要 sudo 免密权限, 失败静默忽略.
if [ "${AVAHI_RESET:-0}" = "1" ] && command -v avahi-browse >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
  if sudo -n systemctl restart avahi-daemon >/dev/null 2>&1; then
    echo "已重启 avahi-daemon (AVAHI_RESET=1), mDNS 缓存已清空" >&2
  fi
fi
if command -v dns-sd >/dev/null 2>&1; then
  start_discovery dns-sd -L "$SVC_ID" "$DNS_DOMAIN" local.
elif command -v avahi-browse >/dev/null 2>&1; then
  # 不能加 -t: avahi-browse -t 会在 dump 完当前列表后立即退出, 此时手机还没扫码广播,
  # dump 为空 -> FIFO 关闭 -> 脚本立刻结束. 去掉 -t 保持持续监听 (与 dns-sd -L 一致),
  # 由外层 timeout/perl 在 PAIR_TIMEOUT 后终止.
  start_discovery avahi-browse -r "$DNS_DOMAIN"
else
  rm -rf "$fifo_dir"
  die "未找到 mDNS 工具 (macOS 自带 dns-sd; Linux 请安装 avahi-utils)"
fi
discover_pid=$!
exec 3<"$fifo"

pair_ok=0
host=
port=
last_host=
avahi_skip=0
while IFS= read -r line <&3; do
  case "$line" in
    *"can be reached at"*)        # dns-sd (macOS)
      addr=${line##*can be reached at }
      addr=${addr%% *}             # 去掉行尾的 "(interface N)"
      case "$addr" in
        \[*\]:*)                  # IPv6: [fe80::1]:port
          host=${addr%%]:*}
          host=${host#[}
          port=${addr##*:}
          case "$host" in
            fe80:*)               # link-local 无 zone 索引无法路由, 跳过等 IPv4 记录
              continue
              ;;
          esac
          ;;
        *)
          host=${addr%%:*}
          port=${addr##*:}
          ;;
      esac
      if [ -n "$host" ] && [ -n "$port" ]; then
        if try_pair "$addr" "$host" "$port"; then
          pair_ok=1
          break
        fi
      fi
      host=
      port=
      ;;
    *"address = ["*|*"port = ["*)  # avahi-browse (Linux)
      # 注意: 模式里的 [ 必须加引号, 否则 POSIX sh (dash) 会当作通配符字符类
      [ "$avahi_skip" = "1" ] && continue
      case "$line" in
        *"address = ["*) host=${line##*"address = ["}; host=${host%%]*} ;;
        *"port = ["*) port=${line##*"port = ["}; port=${port%%]*} ;;
      esac
      if [ -n "$host" ] && [ -n "$port" ]; then
        if try_pair "$host:$port" "$host" "$port"; then
          pair_ok=1
          break
        fi
        host=
        port=
      fi
      ;;
    "+ "*|"- "*|"= "*)        # avahi 服务事件行: + <接口> <协议> <实例> ...
      # 1) 跳过 VPN/代理虚拟接口 (tun/utun/wg 等) 广播的服务, 避免拿到假 IP (如 192.168.139.x) 去配对
      # 2) 只处理实例名 == SVC_ID 的广播 (avahi-browse 不能像 dns-sd -L 那样按实例名过滤;
      #    不过滤会把其他设备/历史会话的配对实例也拿去配对, 用错误的 PSK 握手必然失败)
      set -- $line
      case "${2:-}" in
        tun*|utun*|wg*|tap*|virbr*|docker*|br-*|tailscale*|Meta*|sing-box*) avahi_skip=1 ;;
        *)
          if [ "$SVC_ID" = "${4:-}" ]; then avahi_skip=0; else avahi_skip=1; fi
          ;;
      esac
      ;;
  esac
done

# 终止发现进程并清理 (配对成功时立即退出, 不再等超时)
# wait 显式回收后台任务并取退出码: 避免 shell 打印 "Terminated" 噪音;
# 退出码 124 = 等到超时或主动终止 (正常), 其他 = mDNS 工具提前退出
# (avahi-browse 报错, 常见是 avahi-daemon 没运行)
# 注意: 无命令的 exec 重定向会永久作用于当前 shell, 这里绝不能带 2>/dev/null (会吞掉后续所有 stderr)
kill "$discover_pid" 2>/dev/null || true
discover_rc=0
wait "$discover_pid" 2>/dev/null || discover_rc=$?
exec 3<&- || true
rm -rf "$fifo_dir"

# 循环结束后再确认一次: 自动连接可能较慢, 配对其实已成功 (设备稍后才上线)
if [ "$pair_ok" -eq 0 ] && [ -n "$last_host" ] && "$ADB" devices | grep -qF "$last_host:"; then
  echo "配对成功! (设备已连接)"
  "$ADB" devices -l || true
  pair_ok=1
fi

if [ "$pair_ok" -eq 1 ]; then
  exit 0
fi
if [ "$discover_rc" -ne 124 ]; then
  die "mDNS 发现进程提前退出 (退出码 $discover_rc): Linux 常见原因是 avahi-daemon 未运行, 请检查 systemctl status avahi-daemon 后重试"
fi
die "未发现设备/配对未完成, 大概率是 WiFi 网络问题: 手机与电脑不在同一网络, 或路由器开了 AP 隔离/访客隔离. 请依次检查: ① 手机和电脑连接同一个 WiFi ② 未开访客网络/AP 隔离 ③ 手机已扫码且停留在配对页面 ④ 可换一个 WiFi 或开手机热点再试; 若手机提示配对失败, 重新运行本脚本并重新扫码"
