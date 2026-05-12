import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';

/// Logbook 视图：90 天内已完成、且 inLogbook=true 的任务。
///
/// 按 completedAt 降序展示。M1 占位实现 —— 不做按月分组；M2 加入
/// 折叠分组与"清空 Logbook"。
class LogbookPage extends StatelessWidget {
  const LogbookPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return StreamBuilder<List<Task>>(
      stream: db.watchLogbook(),
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
                    Icon(Icons.checklist,
                        color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      l.logbook,
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
                    l.logbookEmpty,
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
