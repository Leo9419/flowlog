import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:provider/provider.dart';

import '../../state/selection_store.dart';
import 'detail_pane.dart';
import 'sidebar.dart';
import 'shell_content.dart';
import 'window_toolbar.dart';

/// 桌面档：≥ 1000px。
///
/// 三栏：[Sidebar] + 中间内容列 + [DetailPane]，由 multi_split_view
/// 提供可拖动分隔条。`selectedTaskId` 为空时退化为双栏（隐藏 DetailPane）。
///
/// 中间内容列把 [WindowToolbar]（仅 macOS）放在顶部，下方是 [ShellContent]，
/// 让搜索框只在内容列宽度里居中、不占 sidebar 上方空间。
class _ContentColumn extends StatelessWidget {
  const _ContentColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        WindowToolbar(),
        Expanded(child: ShellContent()),
      ],
    );
  }
}

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDetail =
        context.watch<SelectionStore>().state.selectedTaskId != null;

    return Scaffold(
      body: MultiSplitView(
        // 切换 detail 显示时改 key 触发重建，避免拖动权重残留。
        key: ValueKey('desktop_split_${showDetail ? "3" : "2"}'),
        axis: Axis.horizontal,
        dividerBuilder: (axis, _, __, ___, ____, _____) => Container(
          color: theme.dividerColor,
        ),
        initialAreas: showDetail
            ? [
                Area(
                  flex: 0.20,
                  min: 0.15,
                  max: 0.30,
                  builder: (_, __) => const Sidebar(),
                ),
                Area(
                  flex: 0.45,
                  min: 0.30,
                  builder: (_, __) => const _ContentColumn(),
                ),
                Area(
                  flex: 0.35,
                  min: 0.20,
                  builder: (_, __) => const DetailPane(),
                ),
              ]
            : [
                Area(
                  flex: 0.22,
                  min: 0.15,
                  max: 0.32,
                  builder: (_, __) => const Sidebar(),
                ),
                Area(
                  flex: 0.78,
                  min: 0.40,
                  builder: (_, __) => const _ContentColumn(),
                ),
              ],
      ),
    );
  }
}
