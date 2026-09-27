# ChatGPT Timezone Guard

解决 ChatGPT 与 Codex 桌面客户端因本地时区与代理出口 IP 不一致触发的风控降智问题。无需修改系统全局时区，也不需要开启全局 TUN 模式。

> 说明：本项目由用户提出需求和实机复现，AI 协助排查代码、调试问题并整理编写成仓库。

---

## 背景

### 降智原因
ChatGPT 桌面端与 Codex 在运行时会上报客户端本地时区与时间。如果代理出口 IP 位于海外，而客户端本地时区为中国标准时间 (UTC+8)，可能会触发风控机制。此时界面虽然依然显示高级模型，但后端请求会被降级到低参数模型，同时缺少思考过程 (Thinking)。

### 现有方案的问题
- 修改系统全局时区：会导致微信、日历、打卡以及本地文件修改时间异常。
- 开启代理软件的全局 TUN 模式：接管系统 DNS 后，容易导致国内站点分配到海外 CDN，造成国内网页和应用访问缓慢。
- 直接在终端注入环境变量：如果应用在后台已有未退出的实例，系统会复用旧进程，新注入的时区不会生效；若未排除本地回环代理，还会导致客户端内部 IPC 通信中断。

---

## 运行机制

脚本对 ChatGPT / Codex 进程单独注入环境变量，与系统其他应用相互隔离：

```
本机系统
 ├── 系统时区：保持原有设置 (UTC+8)
 ├── 国内流量：正常直连，不走代理
 └── ChatGPT / Codex 进程
      ├── TZ：自动匹配节点所在时区 (如 America/Los_Angeles)
      ├── 代理：定向注入指定端口 (如 7897 或 7890)
      ├── 防 DNS 泄露：使用 socks5h 协议，在远端解析域名
      └── 保护本地通信：通过 no_proxy 排除 127.0.0.1，避免内部 IPC 断连
```

---

## 使用方法

### macOS

#### 1. 准备脚本
克隆仓库并赋予脚本执行权限：
```bash
git clone https://github.com/A5he1ter/chatgpt-timezone-guard.git
cd chatgpt-timezone-guard/scripts/macos
chmod +x launch_chatgpt.sh
```

#### 2. 使用自动操作 (Automator) 制作快捷启动图标
1. 打开 macOS 自带的 "自动操作 (Automator)"。
2. 新建文稿，类型选择 "应用程序"。
3. 在左侧库中搜索 "运行 Shell 脚本"，拖入右侧工作区。
4. 将 `scripts/macos/launch_chatgpt.sh` 的内容复制到脚本输入框中。
5. 保存为应用程序，名称可设为 `ChatGPT Launcher`，保存在 "应用程序" 或桌面上。

之后点击该图标即可启动。脚本会自动查询当前出口时区并在屏幕右上角发送系统通知，启动完成后脚本自动退出，不常驻后台。

### Windows

1. 进入 `scripts/windows/` 目录。
2. 右键 `launch_chatgpt.bat`，选择 "创建快捷方式"。
3. 将快捷方式放到桌面，双击运行。

---

## 效果验证

启动客户端后新建空白对话，可以通过以下方式检查：

1. 验证时区  
提问："请告诉我你当前检测到的客户端具体时间、时区和星期几？"  
如果回复显示节点对应时区（如 America/Los_Angeles 或 Asia/Tokyo），说明注入成功。如果仍然是 UTC+8，说明老进程未完全退出。

2. 验证降智状态  
观察回答上方是否有思考用时展开（如 "用时 XX 秒"）。未受风控的高阶模型在处理复杂或逻辑问题时会有完整的推理链。

---

## 常见问题

### 登录时出现 Route Error (400 Invalid content type: text/html)
原因：登录 API 请求未走代理，直连触发了 Cloudflare 拦截页面。  
处理：检查代理软件实际监听的本地端口（例如 Clash Verge 常见为 7897，部分客户端为 7890，Surge 为 6152）。脚本会自动尝试探测系统代理端口，必要时可在脚本开头修改 PROXY_PORT。

### 界面循环提示 "正在重新连接 (Reconnecting...)"
原因：ChatGPT 客户端界面与后台核心服务通过 127.0.0.1 本地通信。如果代理变量未排除本地地址，握手请求会被发往外部代理导致连接超时。  
处理：脚本中已包含 `no_proxy="localhost,127.0.0.1,*.local"` 配置，确保本地回环流量不走代理。

### 代理分流中的 ab.chatgpt.com
原因：`ab.chatgpt.com` 负责实验性功能与灰度下发。如果分流规则仅精确匹配 `chatgpt.com`，该域名可能被判定为直连并触发 30 秒连接超时。  
处理：在分流规则中使用域名后缀匹配：
```yaml
- DOMAIN-SUFFIX,chatgpt.com,PROXY
- DOMAIN-SUFFIX,openai.com,PROXY
- DOMAIN-SUFFIX,oaistatic.com,PROXY
- DOMAIN-SUFFIX,oaiusercontent.com,PROXY
```

---

## 许可证

本项目使用 [MIT License](LICENSE) 授权。
