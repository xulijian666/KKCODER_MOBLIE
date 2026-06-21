# KKCODER Mobile

KKCODER 的移动端 Flutter App，用于通过手机远程操控电脑上的 Claude Code 终端。

## 功能

- **设备配对** — 输入桌面端生成的 6 位 PIN 码完成安全配对
- **会话列表** — 查看所有活跃的 Claude Code 会话，支持下拉刷新
- **远程终端** — 实时输入输出，支持命令发送、输出滚动、文本复制
- **自动重连** — WebSocket 断线后 3 秒自动重连，并通过 seq + replay 补发丢失的消息
- **连接状态** — 顶部指示灯实时显示连接状态（绿/橙/红）
- **灵活连接** — 支持 IP 地址 / 域名，HTTP / HTTPS

## 前置条件

- Flutter 3.x
- Android SDK
- KKCODER 桌面端已开启远程访问功能

## 开发

```bash
flutter pub get
flutter run
```

## 构建 APK

```bash
flutter build apk --release
```

生成文件：`build/app/outputs/flutter-apk/app-release.apk`

## 项目结构

```
lib/
├── main.dart                    # App 入口
├── app.dart                     # MaterialApp 配置、深色主题、路由
├── config.dart                  # 常量配置
├── models/
│   ├── session.dart             # 会话数据模型
│   ├── output_frame.dart        # WebSocket 输出帧
│   └── server_status.dart       # 服务器状态
├── services/
│   ├── api_service.dart         # REST API 客户端（支持 IP/域名、HTTP/HTTPS）
│   ├── websocket_service.dart   # WebSocket 连接管理 + 自动重连
│   ├── storage_service.dart     # Token/配置安全存储
│   └── terminal_service.dart    # 终端输出 16ms 微批处理缓冲
├── screens/
│   ├── pairing_screen.dart      # 配对屏幕（连接服务器 → 输入 PIN）
│   ├── sessions_screen.dart     # 会话列表
│   └── terminal_screen.dart     # 终端屏幕
└── widgets/
    ├── pin_input.dart           # 6 位 PIN 独立输入组件
    └── session_card.dart        # 会话卡片
```

## 使用流程

### 1. 桌面端准备

1. 打开 KKCODER 桌面应用
2. 进入 设置 → 远程开发
3. 开启远程访问，记下显示的地址和端口
4. 点击「生成配对 PIN」，获得 6 位数字（5 分钟有效）

### 2. 手机端配对

1. 打开 KKCODER Mobile
2. 输入桌面端的地址（IP 或域名）和端口
3. 如使用 HTTPS 连接，打开 HTTPS 开关
4. 点击「连接」，验证服务器可达
5. 输入桌面端显示的 6 位 PIN 码
6. 配对成功后自动进入会话列表

### 3. 使用终端

1. 在会话列表中点击要连接的会话
2. 底部输入框输入命令，点击发送或回车
3. 终端输出实时显示，支持文本选择和复制
4. 顶部状态灯：绿色=已连接，橙色=连接中，红色=已断开（自动重连）

### 4. 断开连接

- 在会话列表页点击右上角菜单 →「断开连接」清除 Token
- 下次使用需重新配对

## 网络连接方式

| 方式 | 地址格式 | 协议 | 说明 |
|------|----------|------|------|
| 局域网直连 | `192.168.x.x` | HTTP | 手机和电脑在同一 WiFi |
| WireGuard / Tailscale | VPN 内网 IP | HTTP | VPN 组网 |
| frp 穿透 | `frp.example.com` | HTTP/HTTPS | 自建 frp 服务器 |
| Cloudflare Tunnel | `kkcoder.example.com` | HTTPS | 域名 + TLS |

## 文档

- [三端交互原理](docs/architecture.md) — 手机、云服务器、电脑怎么配合工作
- [详细设计文档](docs/mobile-design.md) — 网络支持、页面结构、协议、性能优化

## 适配设备

- 主要适配：小米 14 (Android 14)
- 最低支持：Android 8.0 (API 26)
- 推荐分辨率：1080p 及以上
