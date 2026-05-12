import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';

/// Anytime 视图：whenType=none / scheduled 的活动任务。
///
/// M1 阶段最小实现 —— 列表 + TaskRow 复用；M2 接入 Things 风样式、
/// 项目内任务合并、跨项目分组。
class AnytimePage extends StatelessWidget {
  const AnytimePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return StreamBuilder<List<Task>>(
      stream: db.watchAnytimeTasks(),
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
                    Icon(Icons.layers,
                        color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      l.anytime,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      tasks.isEmpty ? '' : '${tasks.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                    l.anytimeEmpty,
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
