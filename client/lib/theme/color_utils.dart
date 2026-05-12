import 'package:flutter/material.dart';

/// 颜色编码工具：在 Flutter `Color` 与持久化用的 hex 字符串之间转换。
///
/// 持久化格式：`"#AARRGGBB"`（8 位 ARGB，固定大写）。Drift 中所有
/// `Projects.color` / 未来 `Areas.color` 等列均使用此格式。
///
/// 设计取舍：使用字符串而非 int 是为了同步层（M3）能直接在 JSON 里携带，
/// 不必担心客户端/服务端 32-bit 符号位差异。

/// 把 `Color` 转换成 `#AARRGGBB` 字符串。
String colorToHex(Color color) {
  // 在新版 Flutter 中 `Color.value` 已弃用，按通道取分量更稳。
  final argb = ((color.a * 255).round() & 0xff) << 24 |
      ((color.r * 255).round() & 0xff) << 16 |
      ((color.g * 255).round() & 0xff) << 8 |
      ((color.b * 255).round() & 0xff);
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// 把 `#AARRGGBB` / `#RRGGBB` / `AARRGGBB` / `RRGGBB` 解析成 `Color`。
///
/// 解析失败时返回 [fallback]（默认透明）。
Color hexToColor(String? hex, {Color fallback = const Color(0x00000000)}) {
  if (hex == null) return fallback;
  var raw = hex.trim();
  if (raw.startsWith('#')) raw = raw.substring(1);
  if (raw.length == 6) raw = 'FF$raw';
  if (raw.length != 8) return fallback;
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

/// 把旧的 32-bit ARGB int 颜色（迁移前 `Projects.color` 类型）转 hex。
///
/// 仅用于迁移与少数兼容接口。新代码请使用 [colorToHex]。
String argbIntToHex(int argb) {
  final bounded = argb & 0xFFFFFFFF;
  return '#${bounded.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}
