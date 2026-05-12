import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../state/selection_store.dart';
import '../ai/ai_chat_page.dart';
import '../inbox/inbox_page.dart';
import '../logbook/logbook_page.dart';
import '../projects/project_page.dart';
import '../someday/someday_page.dart';
import '../tags/tag_page.dart';
import '../today/today_page.dart';
import '../upcoming/upcoming_page.dart';

/// 把 [SelectionState.view] 派发到具体的视图组件。
///
/// 这是三档 Shell（mobile / tablet / desktop）共用的"内容区"实现，确保
/// 视图与 Shell 解耦，且窗口尺寸切换时不重建底层页面 state（依赖 Flutter
/// 的 widget identity；同一个 view 在不同 Shell 中渲染成同一棵子树）。
class ShellContent extends StatelessWidget {
  const ShellContent({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SelectionStore>().state;
    return _viewWidget(context, state);
  }

  Widget _viewWidget(BuildContext context, SelectionState state) {
    final l = AppLocalizations.of(context);
    switch (state.view) {
      case SidebarView.today:
        return const TodayPage();
      case SidebarView.inbox:
        return const InboxPage();
      case SidebarView.upcoming:
        return const UpcomingPage();
      case SidebarView.anytime:
        // 用户选择把 Anytime 与 Inbox 合并；保留 enum 兼容旧 selection state，
        // 但 dispatch 走 Inbox。
        return const InboxPage();
      case SidebarView.someday:
        return const SomedayPage();
      case SidebarView.logbook:
        return const LogbookPage();
      case SidebarView.ai:
        return const AiChatPage();
      case SidebarView.project:
        final id = state.entityId;
        if (id == null) return _EmptyView(l.selectAProject);
        return _ProjectByIdView(projectId: id);
      case SidebarView.tag:
        final id = state.entityId;
        if (id == null) return _EmptyView(l.selectATag);
        return _TagByIdView(tagId: id);
      case SidebarView.area:
        // M2 才会真正进入 area 视图；先用 Inbox 兜底（Anytime 已合并掉）。
        return const InboxPage();
      case SidebarView.search:
        return _EmptyView(l.searchComingInM2);
      case SidebarView.settings:
      case SidebarView.trash:
        // Sidebar 已经把 Settings / Trash 接成 Navigator.push；走到这里说明
        // 是异常路径（如外部恢复 state），用 Today 兜底而不是空白。
        return const TodayPage();
    }
  }
}

class _ProjectByIdView extends StatelessWidget {
  const _ProjectByIdView({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return StreamBuilder<Project?>(
      stream: db.watchProjectById(projectId),
      builder: (context, snapshot) {
        final project = snapshot.data;
        if (project == null) {
          return _EmptyView(AppLocalizations.of(context).projectNotFound);
        }
        return ProjectPage(
          projectId: project.id,
          projectName: project.name,
        );
      },
    );
  }
}

class _TagByIdView extends StatelessWidget {
  const _TagByIdView({required this.tagId});
  final String tagId;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    return StreamBuilder<Tag?>(
      stream: db.watchTagById(tagId),
      builder: (context, snapshot) {
        final tag = snapshot.data;
        if (tag == null) {
          return _EmptyView(AppLocalizations.of(context).tagNotFound);
        }
        return TagPage(
          tagId: tag.id,
          tagName: tag.name,
          color: Color(tag.color),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
