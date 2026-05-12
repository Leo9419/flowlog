import 'package:flutter/material.dart';

import 'sidebar.dart';
import 'shell_content.dart';
import 'window_toolbar.dart';

/// 平板档：600 ≤ width < 1000。
///
/// 双栏布局：固定宽 280 的 [Sidebar] + 自适应 [ShellContent]。
/// 任务详情仍走 modal sheet（与 mobile 一致），不开常驻 Detail。
class TabletShell extends StatelessWidget {
  const TabletShell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 280, child: Sidebar()),
          VerticalDivider(width: 1, color: theme.dividerColor),
          const Expanded(
            child: Column(
              children: [
                // 仅 macOS 显示；其他平台 0 高度。放在内容列内部而不是
                // 横跨整窗，让搜索框只在内容栏里居中。
                WindowToolbar(),
                Expanded(child: ShellContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
