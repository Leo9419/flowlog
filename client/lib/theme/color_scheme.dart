import 'package:flutter/material.dart';

/// 品牌色常量。
///
/// 当前保留 flowlog 的品牌粉 `#FF3B6B`；M4 视觉打磨时再决定是否
/// 切换为更接近 Things 的冷蓝。所有 UI 引用应通过 `ColorScheme`
/// 而非直接读取这些常量，方便后续切换。
class FlowBrand {
  const FlowBrand._();

  /// 主品牌色，用作 ColorScheme 的 seed（fallback）。
  static const Color primary = Color(0xFFFF3B6B);

  /// Priority High 等强提醒标记色。
  static const Color accent = Color(0xFFFFB800);

  /// 浅色模式下的中性背景（surface 默认值的"温白"）。
  static const Color neutralLight = Color(0xFFFAFAFA);

  /// 深色模式下的中性背景（贴近 iOS Dark）。
  static const Color neutralDark = Color(0xFF1C1C1E);
}

/// 构造浅色 ColorScheme。
///
/// [seed] 通常来自系统取色（Material You），未提供时回退到
/// [FlowBrand.primary]。除 seed 推导出的色之外，这里手动覆盖了
/// surface / surfaceContainer / outlineVariant 几个 Things 风格高频
/// 使用的 tone，避免 M3 默认调色板偏紫的问题。
ColorScheme buildLightScheme({Color? seed}) {
  final base = ColorScheme.fromSeed(
    seedColor: seed ?? FlowBrand.primary,
    brightness: Brightness.light,
  );
  return base.copyWith(
    surface: const Color(0xFFFFFFFF),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFAFAFC),
    surfaceContainer: const Color(0xFFF5F5F7), // sidebar 背景
    surfaceContainerHigh: const Color(0xFFEEEEF1),
    surfaceContainerHighest: const Color(0xFFE5E5EA),
    outlineVariant: const Color(0xFFE5E5EA), // 轻分隔线
  );
}

/// 构造深色 ColorScheme。
///
/// 同 [buildLightScheme]，但 surface 系列贴近 iOS Dark 的灰阶。
ColorScheme buildDarkScheme({Color? seed}) {
  final base = ColorScheme.fromSeed(
    seedColor: seed ?? FlowBrand.primary,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    surface: const Color(0xFF1C1C1E),
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainerLow: const Color(0xFF1C1C1E),
    surfaceContainer: const Color(0xFF2C2C2E), // sidebar 背景
    surfaceContainerHigh: const Color(0xFF3A3A3C),
    surfaceContainerHighest: const Color(0xFF48484A),
    outlineVariant: const Color(0xFF38383A),
  );
}
