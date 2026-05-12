/// FlowLog 设计 token 总入口。
///
/// 外部调用方一行 import 即可拿到全部 token：
///
/// ```dart
/// import 'package:flowlog_client/theme/tokens.dart';
/// // ...
/// padding: const EdgeInsets.all(FlowSpacing.lg),
/// borderRadius: FlowRadii.brMd,
/// ```
///
/// 注意：`app_theme.dart` 不在此处 export，避免普通组件文件
/// 误把整个 ThemeData builder 拉进编译图；只有 main.dart 等入口
/// 文件需要单独 import 'theme/app_theme.dart'。
library;

export 'color_scheme.dart';
export 'elevation.dart';
export 'radii.dart';
export 'spacing.dart';
export 'typography.dart';
