# ==============================================================================
# ChatGPT & Codex Windows PowerShell Dynamic Launcher
# ==============================================================================

# 1. 默认代理端口（可根据你的客户端修改，如 7897 或 7890）
$ProxyPort = 7897

# 尝试从注册表读取系统代理端口
try {
    $proxyServer = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
    if ($proxyServer -match ':(\d+)') {
        $ProxyPort = $matches[1]
    }
} catch {}

# 2. 探查当前节点的时区
$detectedTz = "America/Los_Angeles"
try {
    $proxyUri = "http://127.0.0.1:$ProxyPort"
    $rawTz = (Invoke-RestMethod -Uri "http://ip-api.com/line?fields=timezone" -Proxy $proxyUri -TimeoutSec 3).Trim()
    if ($rawTz -match '^[A-Za-z_]+/[A-Za-z0-9_+-]+$' -and $rawTz -ne "Asia/Shanghai") {
        $detectedTz = $rawTz
    }
} catch {
    # 备用探测
    try {
        $rawTz = (Invoke-RestMethod -Uri "https://ipinfo.io/timezone" -Proxy $proxyUri -TimeoutSec 3).Trim()
        if ($rawTz -match '^[A-Za-z_]+/[A-Za-z0-9_+-]+$' -and $rawTz -ne "Asia/Shanghai") {
            $detectedTz = $rawTz
        }
    } catch {}
}

# 3. 强杀残留进程，确保环境变量重新加载
Stop-Process -Name "ChatGPT", "Codex" -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# 4. 查找应用安装路径
$appPath = "$env:LOCALAPPDATA\Programs\ChatGPT\ChatGPT.exe"
if (-not (Test-Path $appPath)) {
    $appPath = "$env:LOCALAPPDATA\Programs\Codex\Codex.exe"
}
if (-not (Test-Path $appPath)) {
    # 尝试查找应用包
    $package = Get-AppxPackage -Name "*OpenAI*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($package) {
        $potential = Join-Path $package.InstallLocation "app\ChatGPT.exe"
        if (Test-Path $potential) { $appPath = $potential }
    }
}

if (-not (Test-Path $appPath)) {
    [System.Windows.Forms.MessageBox]::Show("未检测到 ChatGPT / Codex 安装路径，请手动指定。", "提示")
    exit 1
}

# 5. 设置环境变量并拉起进程
$env:TZ = $detectedTz
$env:http_proxy = "http://127.0.0.1:$ProxyPort"
$env:https_proxy = "http://127.0.0.1:$ProxyPort"
$env:all_proxy = "socks5h://127.0.0.1:$ProxyPort"
$env:no_proxy = "localhost,127.0.0.1,*.local"

Start-Process -FilePath $appPath
