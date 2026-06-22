import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 基于 xterm.js 的终端 WebView 组件
class XTermView extends StatefulWidget {
  final void Function(WebViewController controller)? onReady;
  final void Function(String data)? onInput;

  const XTermView({super.key, this.onReady, this.onInput});

  @override
  State<XTermView> createState() => XTermViewState();
}

class XTermViewState extends State<XTermView> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1E1E))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _ready = true);
          widget.onReady?.call(_controller);
        },
      ))
      ..addJavaScriptChannel('FlutterInput', onMessageReceived: (msg) {
        widget.onInput?.call(msg.message);
      })
      ..loadHtmlString(_html);
  }

  /// 向终端写入数据
  void write(String data) {
    if (!_ready) return;
    // 转义反斜杠和反引号，防止 JS 注入问题
    final escaped = data
        .replaceAll('\\', '\\\\')
        .replaceAll('`', '\\`')
        .replaceAll('\$', '\\\$');
    _controller.runJavaScript('window.termWrite(`$escaped`)');
  }

  /// 清空终端
  void clear() {
    if (!_ready) return;
    _controller.runJavaScript('window.termClear()');
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

const _html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; background: #1E1E1E; overflow: hidden; }
  #terminal { width: 100%; height: 100%; overflow-x: auto; }
</style>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/css/xterm.min.css">
<script src="https://cdn.jsdelivr.net/npm/@xterm/xterm@5.5.0/lib/xterm.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@0.11.0/lib/addon-web-links.min.js"></script>
</head>
<body>
<div id="terminal"></div>
<script>
  // 固定尺寸，匹配桌面端 PTY 默认 80 列，不随手机屏幕缩放
  const COLS = 80;
  const ROWS = 50;

  const term = new Terminal({
    cols: COLS,
    rows: ROWS,
    cursorBlink: true,
    fontSize: 11,
    fontFamily: 'Cascadia Mono, Fira Code, Consolas, monospace',
    theme: {
      background: '#1E1E1E',
      foreground: '#D4D4D4',
      cursor: '#D4D4D4',
      selectionBackground: '#264F78',
      black: '#4D4D4D',
      red: '#E06C75',
      green: '#98C379',
      yellow: '#E5C07B',
      blue: '#61AFEF',
      magenta: '#C678DD',
      cyan: '#56B6C2',
      white: '#D4D4D4',
      brightBlack: '#5C6370',
      brightRed: '#E06C75',
      brightGreen: '#98C379',
      brightYellow: '#E5C07B',
      brightBlue: '#61AFEF',
      brightMagenta: '#C678DD',
      brightCyan: '#56B6C2',
      brightWhite: '#FFFFFF',
    },
    allowProposedApi: true,
  });

  const webLinksAddon = new WebLinksAddon.WebLinksAddon();
  term.loadAddon(webLinksAddon);
  term.open(document.getElementById('terminal'));

  // 写入数据
  window.termWrite = function(data) {
    term.write(data);
  };

  // 清空
  window.termClear = function() {
    term.clear();
  };

  // 键盘输入 → 发送给 Flutter
  term.onData(function(data) {
    if (window.FlutterInput) {
      window.FlutterInput.postMessage(data);
    }
  });

  // 不发送 resize，PTY 尺寸由桌面端控制
</script>
</body>
</html>
''';
