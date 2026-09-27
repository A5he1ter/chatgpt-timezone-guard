#!/bin/bash
# ==============================================================================
# ChatGPT & Codex macOS Dynamic Timezone & Proxy Launcher
# 解决本地系统时区与代理节点不一致导致的 ChatGPT/Codex 客户端隐性“降智”问题
# ==============================================================================

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# 1. 获取当前系统代理端口（优先动态获取，支持 Clash Verge Rev / Surge / Mihomo 等）
PROXY_PORT=$(scutil --proxy 2>/dev/null | awk '/HTTPPort/ {print $3; exit}')
PROXY_PORT=${PROXY_PORT:-7897}

# 2. 动态探查当前代理节点的实际时区（通过代理端口发起极轻量 HTTP 探测）
RAW_TZ=$(curl -x "http://127.0.0.1:$PROXY_PORT" -s --connect-timeout 2 -m 3 "http://ip-api.com/line?fields=timezone" 2>/dev/null | tr -d '\r\n')

# 备用 API 探测
if [[ ! "$RAW_TZ" =~ ^[A-Za-z_]+/[A-Za-z0-9_+-]+$ ]] || [ "$RAW_TZ" = "Asia/Shanghai" ]; then
    RAW_TZ=$(curl -x "http://127.0.0.1:$PROXY_PORT" -s --connect-timeout 2 -m 3 "https://ipinfo.io/timezone" 2>/dev/null | tr -d '\r\n')
fi

# 3. 严格正则校验：必须是合法的 IANA 时区（如 America/Los_Angeles、Asia/Tokyo），否则安全兜底
if [[ "$RAW_TZ" =~ ^[A-Za-z_]+/[A-Za-z0-9_+-]+$ ]] && [ "$RAW_TZ" != "Asia/Shanghai" ]; then
    DETECTED_TZ="$RAW_TZ"
else
    DETECTED_TZ="America/Los_Angeles"
fi

# 4. 彻底杀死旧残留进程，并循环等待其完全释放（防止老进程复用导致时区注入失败）
killall "ChatGPT" 2>/dev/null
killall "Codex" 2>/dev/null
while pgrep -x "ChatGPT" >/dev/null || pgrep -x "Codex" >/dev/null; do
    sleep 0.1
done

# 5. 在 macOS 屏幕右上角弹出系统通知
osascript -e "display notification \"已自动匹配节点时区: $DETECTED_TZ (代理端口: $PROXY_PORT)\" with title \"ChatGPT Timezone Guard\"" 2>/dev/null

# 6. 确定客户端应用路径
APP_BIN=""
if [ -d "/Applications/ChatGPT.app" ]; then
    APP_BIN="/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"
elif [ -d "/Applications/Codex.app" ]; then
    APP_BIN="/Applications/Codex.app/Contents/MacOS/Codex"
fi

if [ -z "$APP_BIN" ] || [ ! -f "$APP_BIN" ]; then
    osascript -e 'display alert "未找到 ChatGPT 或 Codex 应用" message "请检查 /Applications 目录下是否存在该应用。"' 2>/dev/null
    exit 1
fi

# 7. 注入环境启动应用
# 关键技术点：
# - TZ: 注入节点时区，规避后端时区比对风控与降智
# - socks5h: 强制远端 DNS 解析，杜绝本地 DNS 泄露 (DNS Leak)
# - no_proxy: 必须排除 localhost 和 127.0.0.1，保护应用内 IPC 和本地服务通信，杜绝断线重连
# - nohup ... </dev/null: 彻底与终端/Automator父进程管道解绑，避免转圈假死或连带退出
nohup env TZ="$DETECTED_TZ" \
    http_proxy="http://127.0.0.1:$PROXY_PORT" \
    https_proxy="http://127.0.0.1:$PROXY_PORT" \
    all_proxy="socks5h://127.0.0.1:$PROXY_PORT" \
    ALL_PROXY="socks5h://127.0.0.1:$PROXY_PORT" \
    no_proxy="localhost,127.0.0.1,*.local" \
    NO_PROXY="localhost,127.0.0.1,*.local" \
    "$APP_BIN" </dev/null >/dev/null 2>&1 &
