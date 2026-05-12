/// 8pt grid 间距 token。
///
/// 通用刻度（xxs–xxxl）覆盖 95% 场景；业务专用项是几个高频的
/// 复合内边距，避免在 UI 层零散硬编码。
class FlowSpacing {
  const FlowSpacing._();

  // —— 通用刻度（8pt grid）——
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // —— 业务专用 ——
  /// 任务行垂直内边距。
  static const double rowVertical = 12;

  /// 任务行水平内边距。
  static const double rowHorizontal = 16;

  /// 视图分组（如 Today 与 Evening 之间）的纵向间距。
  static const double sectionGap = 24;

  /// Sidebar 列表项之间的间距。
  static const double sidebarItemGap = 4;
}
