import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';
import 'tablet_shell.dart';

/// 顶层 Shell：按可用宽度派发到 Mobile / Tablet / Desktop。
///
/// 这是 `main.dart` 的入口（替代旧 [HomePage]）。
/// 派发是 `LayoutBuilder` 直接重建，不做 `AnimatedSwitcher`，避免窗口
/// resize 跨断点时抖动；选中态由全局 `SelectionStore` 持有，所以重建
/// 不会丢失上下文。
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (layoutForWidth(constraints.maxWidth)) {
          case ShellLayout.mobile:
            return const MobileShell();
          case ShellLayout.tablet:
            return const TabletShell();
          case ShellLayout.desktop:
            return const DesktopShell();
        }
      },
    );
  }
}
