/// Elevation / surface tint 强度 token。
///
/// Things 风偏好"无 elevation 的留白 + 极淡分隔"，所以 surface / row
/// 全部为 0；只有 sheet / popover / dialog 这种需要从画面上"浮起来"
/// 的容器才使用阴影。
class FlowElevation {
  const FlowElevation._();

  /// 主表面（Scaffold / AppBar / Card）默认阴影。
  static const double surface = 0;

  /// 列表行默认阴影。
  static const double row = 0;

  /// Bottom sheet。
  static const double sheet = 8;

  /// Popover / overlay menu。
  static const double popover = 12;

  /// Dialog。
  static const double dialog = 16;

  /// M3 surfaceTintColor 强度：0 = 完全不上 tint。
  static const double tintNone = 0.0;
}
