/// 自适应 Shell 三档断点。
///
/// - `< 600`：MobileShell（单栏 + 底部 Tab）
/// - `600 ≤ w < 1000`：TabletShell（双栏：Sidebar + Content）
/// - `≥ 1000`：DesktopShell（三栏：Sidebar + List + DetailPane）
///
/// 选这两个数值是因为：iPhone Pro Max 横屏 ≈ 932；iPad mini 竖屏 = 744；
/// 13" MacBook 全屏 ≥ 1280。把切换点定在 600 / 1000 同时覆盖横竖屏与
/// 桌面 resize。
class FlowBreakpoints {
  const FlowBreakpoints._();

  /// 小于此值用 MobileShell。
  static const double mobileMax = 600;

  /// 小于此值用 TabletShell；等于或大于此值用 DesktopShell。
  static const double tabletMax = 1000;
}

enum ShellLayout { mobile, tablet, desktop }

ShellLayout layoutForWidth(double width) {
  if (width < FlowBreakpoints.mobileMax) return ShellLayout.mobile;
  if (width < FlowBreakpoints.tabletMax) return ShellLayout.tablet;
  return ShellLayout.desktop;
}
