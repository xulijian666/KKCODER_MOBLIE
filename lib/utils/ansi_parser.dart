import 'package:flutter/material.dart';

/// ANSI 终端转义码解析器
/// 将 Claude Code 的终端输出转换为可读的彩色文本
class AnsiParser {
  // 匹配所有 CSI 序列: ESC[ ... <final byte>
  // final byte 范围: @A-Z[\]^_`a-z{|}~ (0x40-0x7E)
  static final _csiRegex = RegExp(r'\x1b\[[0-9;]*[A-Za-z`{}|~]');
  // 匹配 OSC 序列: ESC] ... ST (或 BEL)
  static final _oscRegex = RegExp(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)');
  // 匹配其他 ESC 序列: ESC <char>
  static final _escRegex = RegExp(r'\x1b[A-Z\\^_\[\]#()0-9]');
  // 匹配单独的控制字符
  static final _ctrlRegex = RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]');

  /// 解析 ANSI 文本，返回带颜色的 TextSpan 列表
  static List<TextSpan> parse(String text) {
    final spans = <TextSpan>[];
    var currentColor = const Color(0xFFD4D4D4);
    var currentBold = false;
    var buffer = StringBuffer();
    var i = 0;

    while (i < text.length) {
      if (text[i] == '\x1b') {
        // 先输出之前的文本
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: _style(currentColor, currentBold),
          ));
          buffer = StringBuffer();
        }

        // 尝试匹配 CSI 序列: ESC[ ... <letter>
        if (i + 1 < text.length && text[i + 1] == '[') {
          var j = i + 2;
          while (j < text.length && j < i + 64) {
            final c = text.codeUnitAt(j);
            if (c >= 0x40 && c <= 0x7E) {
              // 找到 final byte
              final finalChar = text[j];
              if (finalChar == 'm') {
                // SGR (颜色/样式) - 解析参数
                final params = text.substring(i + 2, j);
                _applySgr(params, (c, b) {
                  if (c != null) currentColor = c;
                  currentBold = b;
                });
              }
              // 其他 CSI 序列（光标、清屏等）直接跳过
              i = j + 1;
              break;
            }
            j++;
          }
          if (j >= text.length || j >= i + 64) {
            // 不完整的序列，跳过 ESC
            i++;
          }
        }
        // OSC 序列: ESC] ... ST
        else if (i + 1 < text.length && text[i + 1] == ']') {
          var j = i + 2;
          while (j < text.length) {
            if (text[j] == '\x07') {
              i = j + 1;
              break;
            }
            if (text[j] == '\x1b' && j + 1 < text.length && text[j + 1] == '\\') {
              i = j + 2;
              break;
            }
            j++;
          }
          if (j >= text.length) i = j;
        }
        // 其他 ESC 序列
        else {
          i += 2;
        }
      }
      // 跳过裸控制字符（回车保留，换行保留）
      else if (_ctrlRegex.hasMatch(text[i])) {
        final code = text.codeUnitAt(i);
        if (code == 10) {
          buffer.write('\n'); // 换行
        }
        // 忽略其他控制字符（\r, \t, bell, backspace 等）
        i++;
      }
      // 普通可打印字符
      else {
        buffer.write(text[i]);
        i++;
      }
    }

    if (buffer.isNotEmpty) {
      spans.add(TextSpan(
        text: buffer.toString(),
        style: _style(currentColor, currentBold),
      ));
    }

    // 合并相邻同色 span
    return _mergeSpans(spans);
  }

  /// 纯文本模式：去除所有 ANSI 转义码，只保留可读文本
  static String strip(String text) {
    var result = text;
    result = result.replaceAll(_oscRegex, '');
    result = result.replaceAll(_csiRegex, '');
    result = result.replaceAll(_escRegex, '');
    result = result.replaceAll(_ctrlRegex, '');
    // 清理多余空行
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return result.trim();
  }

  /// 应用 SGR（颜色/样式）参数
  static void _applySgr(String params, void Function(Color? color, bool bold) apply) {
    if (params.isEmpty) {
      apply(null, false);
      return;
    }

    final codes = params.split(';').map((s) => int.tryParse(s) ?? 0).toList();
    var color = const Color(0xFFD4D4D4);
    var bold = false;
    var i = 0;

    while (i < codes.length) {
      final c = codes[i];
      switch (c) {
        case 0:
          color = const Color(0xFFD4D4D4);
          bold = false;
        case 1:
          bold = true;
        case 22:
          bold = false;
        // 标准前景色
        case 30: color = const Color(0xFF4D4D4D);
        case 31: color = const Color(0xFFE06C75);
        case 32: color = const Color(0xFF98C379);
        case 33: color = const Color(0xFFE5C07B);
        case 34: color = const Color(0xFF61AFEF);
        case 35: color = const Color(0xFFC678DD);
        case 36: color = const Color(0xFF56B6C2);
        case 37: color = const Color(0xFFD4D4D4);
        // 扩展前景色
        case 38:
          if (i + 1 < codes.length) {
            if (codes[i + 1] == 2 && i + 4 < codes.length) {
              // RGB: 38;2;r;g;b
              color = Color.fromARGB(255,
                codes[i + 2].clamp(0, 255),
                codes[i + 3].clamp(0, 255),
                codes[i + 4].clamp(0, 255),
              );
              i += 4;
            } else if (codes[i + 1] == 5 && i + 2 < codes.length) {
              // 256色: 38;5;n
              color = _color256(codes[i + 2]);
              i += 2;
            }
          }
        case 39:
          color = const Color(0xFFD4D4D4);
        // 亮前景色
        case 90: color = const Color(0xFF5C6370);
        case 91: color = const Color(0xFFFF6B6B);
        case 92: color = const Color(0xFF69DB7C);
        case 93: color = const Color(0xFFFFD93D);
        case 94: color = const Color(0xFF74C0FC);
        case 95: color = const Color(0xFFDA77F2);
        case 96: color = const Color(0xFF66D9E8);
        case 97: color = const Color(0xFFFFFFFF);
        // 忽略背景色 (40-49, 100-107) 和其他参数
      }
      i++;
    }
    apply(color, bold);
  }

  static Color _color256(int n) {
    if (n < 16) {
      const table = [
        0xFF4D4D4D, 0xFFE06C75, 0xFF98C379, 0xFFE5C07B,
        0xFF61AFEF, 0xFFC678DD, 0xFF56B6C2, 0xFFD4D4D4,
        0xFF5C6370, 0xFFE06C75, 0xFF98C379, 0xFFE5C07B,
        0xFF61AFEF, 0xFFC678DD, 0xFF56B6C2, 0xFFFFFFFF,
      ];
      return Color(table[n]);
    } else if (n < 232) {
      final idx = n - 16;
      return Color.fromARGB(255,
        (idx ~/ 36) * 51,
        ((idx % 36) ~/ 6) * 51,
        (idx % 6) * 51,
      );
    } else {
      final g = 8 + (n - 232) * 10;
      return Color.fromARGB(255, g, g, g);
    }
  }

  static TextStyle _style(Color color, bool bold) {
    return TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
  }

  /// 合并相邻的相同样式 TextSpan
  static List<TextSpan> _mergeSpans(List<TextSpan> spans) {
    if (spans.length <= 1) return spans;
    final merged = <TextSpan>[];
    for (final span in spans) {
      if (merged.isNotEmpty) {
        final last = merged.last;
        if (last.style?.color == span.style?.color &&
            last.style?.fontWeight == span.style?.fontWeight) {
          merged[merged.length - 1] = TextSpan(
            text: (last.text ?? '') + (span.text ?? ''),
            style: last.style,
          );
          continue;
        }
      }
      merged.add(span);
    }
    return merged;
  }
}
