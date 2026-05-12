import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';

/// Someday 视图：whenType=someday 的活动任务。
///
/// M1 占位实现：直接走 watchSomedayTasks 的最小列表；M2 接入分组与
/// "搬入 Anytime" 的拖拽语义。
class SomedayPage extends StatelessWidget {
  const SomedayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 800;

    // 用户偏好将"将来"理解为"未来日期的任务"，所以用 watchFutureTasks
    // 而不是 watchSomedayTasks（whenType=someday，纯模糊"有空再说"）。
    return StreamBuilder<List<Task>>(
      stream: db.watchFutureTasks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data!;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined,
                        color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      l.someday,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    l.somedayEmpty,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: tasks.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: theme.dividerColor,
                  indent: 24,
                  endIndent: 24,
                ),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TaskRow(task: tasks[i], db: db, isWide: isWide),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 64)),
          ],
        );
      },
    );
  }
}
