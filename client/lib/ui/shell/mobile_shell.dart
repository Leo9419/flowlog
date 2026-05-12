import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/selection_store.dart';
import 'shell_content.dart';

/// 手机档：< 600px。
///
/// 顶部不放 AppBar（每个旧 page 自带），底部 NavigationBar 5 项。
/// 任务详情走全屏 push（在 TaskRow 里仍走 modal sheet，等 M2 改）。
class MobileShell extends StatelessWidget {
  const MobileShell({super.key});

  /// 与 NavigationBar 5 个图标一一对应。
  ///
  /// Anytime 与 Inbox 语义合并到 Inbox；Upcoming 重命名为"日历"（视图本身
  /// 不变，仍指向 UpcomingPage）；末位用 Logbook 占第 5 位平衡布局。
  static const _tabs = <SidebarView>[
    SidebarView.today,
    SidebarView.upcoming,
    SidebarView.inbox,
    SidebarView.someday,
    SidebarView.logbook,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SelectionStore>().state;
    final l = AppLocalizations.of(context);
    final tabIndex = _tabs.indexOf(state.view).clamp(0, _tabs.length - 1);

    return Scaffold(
      body: const SafeArea(
        bottom: false,
        child: ShellContent(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.wb_sunny_outlined),
            selectedIcon: const Icon(Icons.wb_sunny),
            label: l.today,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l.calendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inbox_outlined),
            selectedIcon: const Icon(Icons.inbox),
            label: l.inbox,
          ),
          NavigationDestination(
            icon: const Icon(Icons.archive_outlined),
            selectedIcon: const Icon(Icons.archive),
            label: l.someday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.checklist_rtl),
            selectedIcon: const Icon(Icons.checklist),
            label: l.logbook,
          ),
        ],
        onDestinationSelected: (i) =>
            context.read<SelectionStore>().selectView(_tabs[i]),
      ),
    );
  }
}
