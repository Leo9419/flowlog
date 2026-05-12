# M1-05 主题与设计 Token

> 把品牌主题、间距、字体、圆角等设计 token 集中到 `client/lib/theme/`，让 M2 的视图重写直接消费 token，不再硬编码。M1 阶段只搭框架与默认值，不重写 task_row 等组件视觉。

## 1. 目标

- 集中管理 Light / Dark / Material You 三套主题入口。
- 提供 Spacing / Typography / Radii / Elevation / Color 五类 token。
- 与 `dynamic_color`（M1-03）协作：Android 12+ 取系统色，其他平台回退品牌色。
- 不破坏现有 UI（M1 阶段视觉看上去与之前一致或更接近 Things，但不大改）。

## 2. 现状

`client/lib/main.dart` 直接：
```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF3B6B)),
  useMaterial3: true,
),
```

问题：
- 硬编码粉色种子；不支持 Material You
- 没有间距 / 圆角 / 字体 token
- Light / Dark 无独立调色配置

## 3. 文件结构

```
client/lib/theme/
├── app_theme.dart        # 入口：appLightTheme / appDarkTheme
├── color_scheme.dart     # 品牌色 + ColorScheme 构造
├── spacing.dart          # 8pt grid token
├── radii.dart            # 圆角 token
├── elevation.dart        # 阴影 / surface tint token
├── typography.dart       # TextTheme（按平台用 SF / Inter / Roboto）
└── tokens.dart           # 汇总 import，方便外部一行 import
```

## 4. Token 详细设计

### 4.1 Spacing — 8pt grid

`client/lib/theme/spacing.dart`：
```dart
class FlowSpacing {
  FlowSpacing._();
  static const double xxs = 2;
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // 业务专用
  static const double rowVertical    = 12;   // 任务行上下内边距
  static const double rowHorizontal  = 16;
  static const double sectionGap     = 24;   // 视图分组之间
  static const double sidebarItemGap = 4;
}

const fs = FlowSpacing;   // 简写：fs.lg
```

### 4.2 Radii

`client/lib/theme/radii.dart`：
```dart
class FlowRadii {
  FlowRadii._();
  static const double sm   = 6;
  static const double md   = 10;
  static const double lg   = 14;
  static const double xl   = 20;
  static const double pill = 999;

  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);

  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
}
```

### 4.3 Elevation

Things 风格 = 几乎不用 elevation，只在 sheet/popover 上用淡阴影。

`client/lib/theme/elevation.dart`：
```dart
class FlowElevation {
  FlowElevation._();
  static const double surface  = 0;
  static const double row      = 0;
  static const double sheet    = 8;
  static const double popover  = 12;
  static const double dialog   = 16;

  // M3 surfaceTintColor 强度：0 = 无 tint
  static const double tintNone = 0.0;
}
```

### 4.4 Typography

平台字体差异：

| 平台 | 字体 | 备注 |
|---|---|---|
| iOS / macOS | `.SF Pro Text` / `.SF Pro Display`（系统字体）| Flutter 默认，留空即可 |
| Android | `Roboto` 或 `Inter`（M2 评估） | 系统默认 |
| Windows / Linux | 系统字体 | 暂不优化 |

`client/lib/theme/typography.dart`：

```dart
TextTheme buildTextTheme({required Brightness brightness}) {
  // M3 baseline → 微调字号与字重
  final base = brightness == Brightness.light
      ? Typography.material2021(platform: defaultTargetPlatform).black
      : Typography.material2021(platform: defaultTargetPlatform).white;

  return base.copyWith(
    // 大标题（视图 hero 标题，如 "Today"）
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.5),
    // 项目名 / sidebar 大标题
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
    // 任务标题
    titleMedium:   base.titleMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 15, height: 1.3),
    // 任务 notes / 副文本
    bodyMedium:    base.bodyMedium?.copyWith(fontSize: 13, height: 1.4),
    // 标签 / 元信息（日期、tag chip）
    labelMedium:   base.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
  );
}
```

### 4.5 Color & ColorScheme

#### 品牌色决策

Things 用偏冷的蓝色 `#1E88E5` 作为强调。flowlog 现有粉色 `#FF3B6B` 偏活泼。M1 默认保留粉色但改名 `brandPrimary`，M4 视觉打磨阶段再决定是否改色。

`client/lib/theme/color_scheme.dart`：
```dart
class FlowBrand {
  FlowBrand._();
  static const Color primary = Color(0xFFFF3B6B);   // 当前粉色，M4 可换
  static const Color accent  = Color(0xFFFFB800);   // 黄色（priority high 标记）
  static const Color neutralLight = Color(0xFFFAFAFA);
  static const Color neutralDark  = Color(0xFF1C1C1E); // 接近 iOS Dark
}

ColorScheme buildLightScheme({Color? seed}) {
  final s = seed ?? FlowBrand.primary;
  return ColorScheme.fromSeed(
    seedColor: s,
    brightness: Brightness.light,
  ).copyWith(
    surface:           const Color(0xFFFFFFFF),
    surfaceContainer:  const Color(0xFFF5F5F7),  // sidebar 背景
    surfaceContainerHigh: const Color(0xFFEEEEF1),
    outlineVariant:    const Color(0xFFE5E5EA),  // 轻分隔线
  );
}

ColorScheme buildDarkScheme({Color? seed}) {
  final s = seed ?? FlowBrand.primary;
  return ColorScheme.fromSeed(
    seedColor: s,
    brightness: Brightness.dark,
  ).copyWith(
    surface:           const Color(0xFF1C1C1E),
    surfaceContainer:  const Color(0xFF2C2C2E),  // sidebar 背景
    surfaceContainerHigh: const Color(0xFF3A3A3C),
    outlineVariant:    const Color(0xFF38383A),
  );
}
```

### 4.6 入口 ThemeData

`client/lib/theme/app_theme.dart`：

```dart
import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'typography.dart';
import 'radii.dart';
import 'elevation.dart';

ThemeData appLightTheme({Color? seed}) =>
    _buildTheme(buildLightScheme(seed: seed), Brightness.light);

ThemeData appDarkTheme({Color? seed}) =>
    _buildTheme(buildDarkScheme(seed: seed), Brightness.dark);

ThemeData _buildTheme(ColorScheme cs, Brightness b) {
  final tt = buildTextTheme(brightness: b);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: cs,
    textTheme: tt,
    scaffoldBackgroundColor: cs.surface,

    // 去 elevation 化
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.surface,
      centerTitle: false,
      titleTextStyle: tt.headlineSmall,
    ),
    cardTheme: CardTheme(
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.surface,
      shape: RoundedRectangleBorder(borderRadius: FlowRadii.brMd),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant,
      thickness: 0.5,
      space: 0,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: FlowRadii.brMd),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: FlowRadii.brSm),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelStyle: tt.labelMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: FlowRadii.rLg),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: FlowElevation.dialog,
      shape: RoundedRectangleBorder(borderRadius: FlowRadii.brLg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: cs.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(tt.labelMedium),
    ),
    splashFactory: NoSplash.splashFactory,    // 去 Material 涟漪，桌面更安静
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
```

### 4.7 Tokens 汇总

`client/lib/theme/tokens.dart`：
```dart
export 'spacing.dart';
export 'radii.dart';
export 'elevation.dart';
export 'color_scheme.dart';
```

外部使用：
```dart
import 'package:flowlog/theme/tokens.dart';
// ...
padding: EdgeInsets.all(FlowSpacing.lg),
borderRadius: FlowRadii.brMd,
```

## 5. main.dart 接入

参考 M1-04 的 main.dart 片段：

```dart
DynamicColorBuilder(
  builder: (light, dark) => MaterialApp(
    theme: appLightTheme(seed: light?.primary),
    darkTheme: appDarkTheme(seed: dark?.primary),
    themeMode: settings.themeMode,
    home: ...,
  ),
);
```

`AppSettings` 已有 `themeMode` 字段（参考 03_Client_Design 中的 settings 模型），M1 直接用。

## 6. 兼容性策略

- M1 不动 `task_row.dart` 等老组件——它们继续用默认 ThemeData 取色，看上去与之前接近。
- 老组件中的硬编码颜色（如 `Color(0xFFE0E0E0)`）在 M2 统一替换为 `cs.outlineVariant` / `cs.surfaceContainer`。
- M1 提交时增加 lint 规则（可选）：禁止在 `lib/ui/` 下出现 `Color(0x...)` 硬编码（用 `analysis_options.yaml` 自定义规则或脚本扫描）。

## 7. 文件清单

### 新增
```
client/lib/theme/app_theme.dart
client/lib/theme/color_scheme.dart
client/lib/theme/spacing.dart
client/lib/theme/radii.dart
client/lib/theme/elevation.dart
client/lib/theme/typography.dart
client/lib/theme/tokens.dart
```

### 修改
```
client/lib/main.dart       # 接入 appLightTheme / appDarkTheme
client/pubspec.yaml        # （依赖 dynamic_color 已在 M1-03 加）
```

## 8. 实施步骤

1. `feat(theme): scaffold spacing/radii/elevation tokens`
2. `feat(theme): light & dark ColorScheme builders with seed override`
3. `feat(theme): typography with cross-platform fallbacks`
4. `feat(theme): unified app_theme + component theme overrides`
5. `chore(main): wire DynamicColorBuilder + new theme builders`
6. `chore(visual): manual diff old vs new on macOS / iOS / Android` — 截图对比，必要时微调

## 9. 风险与注意事项

| 风险 | 应对 |
|---|---|
| `surfaceContainer` 在 Flutter 旧版本不存在 | 要求 Flutter 3.22+；`pubspec.yaml` 加 `environment.flutter: '>=3.22.0'` |
| 去 elevation 后桌面端层级不清 | 用 `outlineVariant` 描边代替 elevation 区分 |
| iOS 字体看上去过细 | `titleMedium` 的 `fontWeight` 改为 `w500`，必要时为 iOS 单独提一档 |
| Material You 取到深紫色破坏品牌识别 | 在 settings 加 "使用品牌色 / 跟随系统色" 开关（M2 实装 UI），M1 让 `seed` 可被设置覆盖 |
| 老组件颜色不一致 | M1 不强制改老组件，仅记录到 M2 重写清单 |
| ChipTheme 不影响 InputChip / FilterChip | M2 出现具体场景时再单独 override，不在 M1 完美化 |

## 10. 验收标准

1. ✅ `import 'package:flowlog/theme/tokens.dart';` 可一次性引入所有 token。
2. ✅ macOS / iOS / Android 启动后 light / dark 切换正常。
3. ✅ Android 12+ 改壁纸后强调色跟随变化（M1-03 配合）。
4. ✅ Settings 切换 themeMode（system / light / dark）即时生效，无重启需求。
5. ✅ 现有 task_row / sidebar / Today 视图视觉无明显回退（人工对比截图）。
6. ✅ 全局 elevation 默认 0，bottom sheet / dialog 仅保留淡阴影。
