# KKCODER Mobile 详细设计文档

## 1. 概述

KKCODER Mobile 是 KKCODER 桌面应用的移动端配套 App，基于 Flutter 开发，主要适配 Android（小米 14）。通过 WebSocket 连接桌面端的 axum 远程访问服务器，实现手机远程操控 Claude Code 终端。

### 1.1 核心能力

| 能力 | 说明 |
|------|------|
| 设备配对 | PIN 码配对，Token 鉴权 |
| 会话列表 | 拉取活跃会话，下拉刷新 |
| 远程终端 | 实时输入输出，文本可复制 |
| 断线重连 | 3 秒自动重连 + seq/replay 补发 |
| 协议支持 | IP / 域名，HTTP / HTTPS |

### 1.2 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart 3.9) |
| 状态管理 | ChangeNotifier + ListenableBuilder |
| 网络 | http (REST) + web_socket_channel (WebSocket) |
| 存储 | flutter_secure_storage (Token/配置加密存储) |
| 主题 | Material 3 深色主题 |
| 构建 | flutter build apk --release |

---

## 2. 网络连接支持

### 2.1 地址类型

| 类型 | 示例 | 说明 |
|------|------|------|
| IPv4 | `192.168.1.100` | 局域网直连 |
| IPv6 | `::1` / `[fe80::1]` | 本地回环 |
| 域名 | `kkcoder.example.com` | frp / Cloudflare Tunnel / 自建域名 |

### 2.2 协议支持

| 协议 | URL 格式 | WebSocket | 场景 |
|------|----------|-----------|------|
| HTTP | `http://host:port` | `ws://host:port` | 局域网直连、内网 frp |
| HTTPS | `https://host:port` | `wss://host:port` | 公网域名、Cloudflare Tunnel |

用户在配对页面通过 **HTTPS 开关** 切换协议，选择自动保存。

### 2.3 URL 构建逻辑

```
输入: host="kkcoder.example.com", port=443, https=true
REST: https://kkcoder.example.com:443/api/status
WS:   wss://kkcoder.example.com:443/api/sessions/{id}/ws?token=xxx

输入: host="192.168.1.100", port=9527, https=false
REST: http://192.168.1.100:9527/api/status
WS:   ws://192.168.1.100:9527/api/sessions/{id}/ws?token=xxx
```

---

## 3. 页面结构

### 3.1 页面流程

```
┌─────────────┐
│  配对屏幕    │  ← 输入地址、端口、HTTPS 开关
│  (连接服务器) │
└──────┬──────┘
       │ 连接成功
       ▼
┌─────────────┐
│  配对屏幕    │  ← 输入 6 位 PIN 码
│  (PIN 验证)  │
└──────┬──────┘
       │ 验证成功，保存 Token
       ▼
┌─────────────┐
│  会话列表    │  ← 显示所有活跃会话
└──────┬──────┘
       │ 点击会话
       ▼
┌─────────────┐
│  终端屏幕    │  ← WebSocket 实时输入输出
└─────────────┘
```

### 3.2 配对屏幕 (`pairing_screen.dart`)

**第一步：连接服务器**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 服务器地址 | 文本 | 是 | IP 地址或域名 |
| 端口 | 数字 | 是 | 1-65535，无默认值 |
| HTTPS | 开关 | 否 | 默认关闭 |

验证流程：
1. 检查地址和端口非空
2. 检查端口范围 1-65535
3. GET `/api/status` 验证服务器可达
4. 保存连接配置到本地

**第二步：PIN 验证**

| 组件 | 说明 |
|------|------|
| PIN 输入 | 6 位独立数字输入框，自动跳格 |
| 更换服务器 | 返回第一步 |

验证流程：
1. POST `/api/pair/verify` 发送 `{pin, deviceName}`
2. 服务端返回 Token (UUID v4)
3. Token 存入 flutter_secure_storage
4. 跳转会话列表

### 3.3 会话列表 (`sessions_screen.dart`)

| 功能 | 说明 |
|------|------|
| 获取列表 | GET `/api/sessions`，Bearer Token 鉴权 |
| 下拉刷新 | RefreshIndicator |
| 会话卡片 | 显示名称、项目、类型图标 |
| 断开连接 | 清除 Token，返回配对屏幕 |

### 3.4 终端屏幕 (`terminal_screen.dart`)

| 区域 | 说明 |
|------|------|
| 顶部栏 | 会话名称 + 连接状态灯 + 清屏按钮 |
| 终端区域 | 深色背景，等宽字体，SelectableText（可复制） |
| 输入栏 | 底部固定，输入框 + 发送按钮 |

连接状态灯：
- 绿色：已连接
- 橙色：连接中
- 红色：已断开（自动重连中）

---

## 4. 服务层

### 4.1 ApiService (`services/api_service.dart`)

```dart
class ApiService {
  void configure(String host, int port, {bool https = false});
  Future<ServerStatus> getStatus();
  Future<String> verifyPin(String pin, String deviceName);
  Future<List<Session>> getSessions(String token);
  String wsUrl(String sessionId, String token);
}
```

所有方法通过 `Uri.parse()` 构建 URL，天然支持 IP 和域名。

### 4.2 WebSocketService (`services/websocket_service.dart`)

```dart
class WebSocketService {
  void connect(String url);        // 连接 ws:// 或 wss://
  void send(String data);          // 发送原始 JSON
  void sendInput(String text);     // {"type":"input","data":"..."}
  void sendResize(int cols, int rows); // {"type":"resize","cols":N,"rows":N}
  void disconnect();
  Stream<String> get output;       // PTY 输出数据流
  Stream<WsState> get stateStream; // 连接状态流
}
```

自动重连机制：
- 断线后 3 秒自动重连
- 重连后发送 `{"type":"replay","last_seq":N}` 补发丢失消息
- `lastSeq` 持续更新，确保 replay 准确

### 4.3 StorageService (`services/storage_service.dart`)

| Key | 类型 | 说明 |
|-----|------|------|
| `auth_token` | String | 鉴权 Token |
| `server_host` | String | 服务器地址（IP 或域名） |
| `server_port` | int | 端口号 |
| `use_https` | bool | 是否使用 HTTPS |
| `device_name` | String | 设备名称 |

### 4.4 TerminalService (`services/terminal_service.dart`)

- 接收 WebSocketService 的输出流
- 16ms 定时器微批处理，避免逐帧刷新
- 输出超过 100KB 自动裁剪前部内容
- 通过 ChangeNotifier 通知 UI 更新

---

## 5. 数据模型

### 5.1 Session (`models/session.dart`)

```dart
class Session {
  final String id;              // 会话 ID
  final String name;            // 会话名称
  final String project;         // 所属项目
  final String type;            // "claude" 或 "pi"
  final String agentSessionId;  // Agent 会话 ID
  final String? createdAt;      // 创建时间
  final String? lastUserMessageAt; // 最后用户消息时间
}
```

### 5.2 OutputFrame (`models/output_frame.dart`)

```dart
class OutputFrame {
  final int seq;         // 帧序号（用于 replay）
  final String sessionId;
  final String data;     // PTY 输出内容
  final int timestamp;   // 毫秒时间戳
}
```

### 5.3 ServerStatus (`models/server_status.dart`)

```dart
class ServerStatus {
  final bool running;        // 服务器是否运行
  final int port;            // 监听端口
  final int activeSessions;  // 活跃会话数
}
```

---

## 6. WebSocket 协议

### 6.1 客户端 → 服务端

**发送输入**
```json
{"type": "input", "data": "用户输入的文本\r"}
```

**调整终端大小**
```json
{"type": "resize", "cols": 80, "rows": 24}
```

**断线重连补发请求**
```json
{"type": "replay", "last_seq": 1020}
```

### 6.2 服务端 → 客户端

**PTY 输出**
```json
{
  "type": "pty_output",
  "seq": 1024,
  "session_id": "abc123",
  "data": "Claude Code 输出内容...",
  "timestamp": 1718976000000
}
```

**会话状态**
```json
{"type": "session_status", "status": "busy"}
```

**补发完成**
```json
{"type": "replay_complete", "replayed_count": 5}
```

### 6.3 断线重连流程

```
1. 客户端检测到连接断开
2. 等待 3 秒
3. 重新建立 WebSocket 连接
4. 发送 {"type": "replay", "last_seq": 1020}
5. 服务端从 ring buffer 补发 seq > 1020 的帧
6. 服务端发送 {"type": "replay_complete", "replayed_count": N}
7. 客户端恢复正常接收模式
```

---

## 7. 性能优化

### 7.1 终端渲染

- 16ms 微批处理：WebSocket 输出写入 buffer，每 16ms flush 一次
- 使用 ListenableBuilder 精确重建，不 rebuild 整个页面
- SelectableText 渲染输出，支持长按复制
- 输出超 100KB 自动裁剪，防止内存膨胀

### 7.2 网络

- 单条 WebSocket 连接，无额外 REST 轮询
- Token 验证在服务端内存完成，不查数据库
- 断线重连走 ring buffer，不丢消息

### 7.3 Android

- minSdkVersion 26，targetSdkVersion 34
- 仅申请 INTERNET 和 ACCESS_NETWORK_STATE 权限
- 支持明文 HTTP（局域网直连需要 `usesCleartextTraffic=true`）

---

## 8. 安全设计

| 措施 | 说明 |
|------|------|
| PIN 码配对 | 6 位随机数字，5 分钟过期 |
| Token 鉴权 | UUID v4，122 位随机性，长期有效 |
| 安全存储 | flutter_secure_storage 加密保存 Token |
| 可吊销 | 桌面端可吊销任意设备的 Token |
| HTTPS | 支持 TLS 加密传输 |

---

## 9. 构建配置

### 9.1 Android 配置

**android/app/src/main/AndroidManifest.xml**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<application android:usesCleartextTraffic="true" ...>
```

**android/app/build.gradle.kts**
```kotlin
minSdk = 26
targetSdk = 34
```

### 9.2 依赖

```yaml
dependencies:
  web_socket_channel: ^3.0.0     # WebSocket
  http: ^1.2.0                   # REST API
  flutter_secure_storage: ^10.0.0 # Token 安全存储
  provider: ^6.1.0               # 状态管理
  google_fonts: ^6.0.0           # 等宽字体
```

### 9.3 构建命令

```bash
# 开发
flutter pub get
flutter run

# Release APK
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

---

## 10. 适配说明

| 设备 | 状态 |
|------|------|
| 小米 14 (Android 14) | 主要适配目标 |
| Android 8.0+ (API 26+) | 最低支持 |
| 1080p+ | 推荐分辨率 |
| 竖屏 | 锁定竖屏显示 |
