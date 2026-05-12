import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../state/selection_store.dart';
import '../../theme/tokens.dart';
import '../settings/settings_page.dart';
import '../trash/trash_page.dart';
import 'sidebar_item.dart';

/// Tablet / Desktop 共用的左侧导航。
///
/// 6 个固定视图 + Trash / Settings；Areas / Projects / Tags 动态部分
/// 在 M2 接入（doc §5.6 列了 TODO，本文件保留占位区域）。
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const primaryViews = <SidebarView>[
    SidebarView.inbox,
    SidebarView.today,
    SidebarView.upcoming,
    SidebarView.someday,
    SidebarView.logbook,
    SidebarView.ai,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: ListView(
          // 顶部预留 ~28px 给 macOS title bar：traffic light 浮在那块上面
          // （和内容列的 WindowToolbar 上半区一样的高度），避免 sidebar
          // 里的 widget 与红黄绿按钮叠图。
          padding: const EdgeInsets.fromLTRB(0, 32, 0, FlowSpacing.sm),
          children: [
            // —— App 标题 ——
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpacing.lg,
                0,
                FlowSpacing.lg,
                FlowSpacing.lg,
              ),
              child: Text(
                l.appTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // —— 6 个固定视图 ——
            // Inbox 显示未分配的活动任务计数
            StreamBuilder<List<Task>>(
              stream: db.watchInboxTasks(),
              builder: (context, snapshot) => SidebarItem(
                view: SidebarView.inbox,
                icon: Icons.inbox_outlined,
                activeIcon: Icons.inbox,
                label: l.inbox,
                color: const Color(0xFF7B8794),
                count: snapshot.data?.length,
              ),
            ),
            StreamBuilder<List<Task>>(
              stream: db.watchTodayTasks(),
              builder: (context, snapshot) => SidebarItem(
                view: SidebarView.today,
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny,
                label: l.today,
                color: const Color(0xFFFFB800),
                count: snapshot.data?.length,
              ),
            ),
            // "Upcoming" 重命名为"日历"——内容仍是按日期分组的未来任务列表，
            // sidebar 上叫"日历"更直观。Anytime 与 Inbox 语义重合，已合并到
            // Inbox。
            SidebarItem(
              view: SidebarView.upcoming,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month,
              label: l.calendar,
              color: const Color(0xFFFF3B6B),
            ),
            SidebarItem(
              view: SidebarView.someday,
              icon: Icons.archive_outlined,
              activeIcon: Icons.archive,
              label: l.someday,
              color: const Color(0xFF9F84BD),
            ),
            SidebarItem(
              view: SidebarView.logbook,
              icon: Icons.checklist_rtl,
              activeIcon: Icons.checklist,
              label: l.logbook,
              color: const Color(0xFF6B7280),
            ),
            SidebarItem(
              view: SidebarView.ai,
              icon: Icons.auto_awesome_outlined,
              activeIcon: Icons.auto_awesome,
              label: l.aiChat,
              color: const Color(0xFF5B8DEF),
            ),

            // TODO(M2): 在这里挂 Areas → Projects 动态 StreamBuilder + Tags
            // 列表（参见 M1_04_Adaptive_Shell.md §5.6）。M1 阶段只用一条
            // 分隔线把 6 个固定视图与 Trash / Settings 隔开，不渲染占位文案。
            const SizedBox(height: FlowSpacing.md),
            const Divider(indent: FlowSpacing.lg, endIndent: FlowSpacing.lg),
            const SizedBox(height: FlowSpacing.sm),

            // —— 工具入口 ——
            SidebarItem(
              view: SidebarView.trash,
              icon: Icons.delete_outline,
              label: l.trash,
              color: const Color(0xFFAEB4BC),
              onTapOverride: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrashPage()),
              ),
            ),
            SidebarItem(
              view: SidebarView.settings,
              icon: Icons.settings_outlined,
              label: l.settings,
              color: const Color(0xFFAEB4BC),
              onTapOverride: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
