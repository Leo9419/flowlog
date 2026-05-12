import 'package:flutter/material.dart';

import 'color_scheme.dart';
import 'elevation.dart';
import 'radii.dart';
import 'typography.dart';

/// 浅色主题入口。
///
/// [seed] 通常来自 Material You 系统取色（见 M1_03 的 DynamicColorBuilder
/// 接入），未提供时回退到 [FlowBrand.primary]。
ThemeData appLightTheme({Color? seed}) =>
    _buildTheme(buildLightScheme(seed: seed), Brightness.light);

/// 深色主题入口。同 [appLightTheme]。
ThemeData appDarkTheme({Color? seed}) =>
    _buildTheme(buildDarkScheme(seed: seed), Brightness.dark);

ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
  final tt = buildTextTheme(brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    textTheme: tt,
    scaffoldBackgroundColor: cs.surface,
    canvasColor: cs.surface,
    dividerColor: cs.outlineVariant,

    // —— 表面"去 elevation"化 ——
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.surface,
      scrolledUnderElevation: FlowElevation.surface,
      centerTitle: false,
      titleTextStyle: tt.headlineSmall?.copyWith(color: cs.onSurface),
    ),
    cardTheme: CardThemeData(
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.surface,
      shape: const RoundedRectangleBorder(borderRadius: FlowRadii.brMd),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant,
      thickness: 0.5,
      space: 0,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: FlowRadii.brMd),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(borderRadius: FlowRadii.brSm),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelStyle: tt.labelMedium,
    ),

    // —— 真正需要"浮起"的容器才上阴影 ——
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: FlowRadii.rLg),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.dialog,
      shape: const RoundedRectangleBorder(borderRadius: FlowRadii.brLg),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.popover,
      shape: const RoundedRectangleBorder(borderRadius: FlowRadii.brMd),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: cs.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(tt.labelMedium),
    ),

    // —— 桌面级安静交互 ——
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
