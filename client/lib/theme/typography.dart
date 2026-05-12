import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 构造 TextTheme。
///
/// 以 Material 2021 排版为基线，按 Things 的层级关系微调字号与字重：
/// - displaySmall：视图 hero 标题（"Today" 等）
/// - headlineSmall：项目名 / sidebar 大标题
/// - titleMedium：任务标题
/// - bodyMedium：notes / 副文本
/// - labelMedium：日期、tag chip 等元信息
///
/// 字体族保持 Flutter 默认（iOS / macOS 使用系统 SF；Android 使用
/// Roboto）。M4 评估是否引入 Inter 作为 Android 默认。
TextTheme buildTextTheme({required Brightness brightness}) {
  final base = brightness == Brightness.light
      ? Typography.material2021(platform: defaultTargetPlatform).black
      : Typography.material2021(platform: defaultTargetPlatform).white;

  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 28,
      letterSpacing: -0.5,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 20,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 15,
      height: 1.3,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.4,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );
}
