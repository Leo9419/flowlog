import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../state/selection_store.dart';
import '../task_detail/task_detail_sheet.dart';

/// Desktop 三栏右侧的常驻任务详情。
///
/// 监听 [SelectionStore.selectedTaskId]：
/// * 未选中 → 显示 [_EmptyDetail] 占位
/// * 选中且任务还存在 → 复用 [TaskDetailSheet] 的内容；为隔离它内部的
///   `Navigator.pop`（关闭按钮），用一个嵌入式 [Navigator]，把 pop 转写为
///   清空选中任务（让 DesktopShell 退化回双栏）。
///
/// M1 阶段不抽出独立的 `TaskDetailView`：`TaskDetailSheet` 的 build 方法
/// 已经返回纯内容（无 Scaffold），完全可以嵌入。M2 视图重构若做组件库
/// 抽离，再把 sheet / view 拆开。
class DetailPane extends StatelessWidget {
  const DetailPane({super.key});

  @override
  Widget build(BuildContext context) {
    final taskId = context.watch<SelectionStore>().state.selectedTaskId;
    final db = Provider.of<AppDatabase>(context);
    final theme = Theme.of(context);

    if (taskId == null) {
      return _EmptyDetail(theme: theme);
    }

    return Container(
      color: theme.colorScheme.surface,
      child: StreamBuilder<Task?>(
        stream: (db.select(db.tasks)..where((t) => t.id.equals(taskId)))
            .watchSingleOrNull(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final task = snapshot.data;
          if (task == null) {
            // 任务被删 / 永久清除时优雅退化
            return _EmptyDetail(theme: theme);
          }
          return Navigator(
            // 用 taskId 作为 key 让任务切换时 Navigator 重建，避免旧
            // TaskDetailSheet state 残留。
            key: ValueKey('detail_pane_navigator_$taskId'),
            pages: [
              MaterialPage(
                key: ValueKey('detail_pane_page_$taskId'),
                child: TaskDetailSheet(task: task, db: db),
              ),
            ],
            // M3 评估迁移到 onDidRemovePage：那个 API 要求父组件主动改 pages
            // 列表，与"用 SelectionStore 控制可见性"的现有架构耦合更紧；
            // M1 阶段先沿用已稳定的 onPopPage。
            // ignore: deprecated_member_use
            onPopPage: (route, result) {
              if (!route.didPop(result)) return false;
              context.read<SelectionStore>().clearTask();
              return true;
            },
          );
        },
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              l.selectTaskToSeeDetails,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
