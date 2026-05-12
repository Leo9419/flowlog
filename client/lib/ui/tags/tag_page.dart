import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../task_sort.dart';
import '../widgets/task_row.dart';

class TagPage extends StatelessWidget {
  const TagPage({
    super.key,
    required this.tagId,
    required this.tagName,
    required this.color,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final String tagId;
  final String tagName;
  final Color color;
  final TaskSortMode sortMode;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);
    return StreamBuilder<Tag?>(
      stream: db.watchTagById(tagId),
      builder: (context, snapshot) {
        final tag = snapshot.data;
        final displayName = tag?.name ?? tagName;
        final displayColor = tag == null ? color : Color(tag.color);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: displayColor),
                const SizedBox(width: 8),
                Text(displayName),
              ],
            ),
          ),
          body: StreamBuilder<List<Task>>(
            stream: db.watchTasksByTag(tagId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = sortTasks(snapshot.data!, sortMode);

              if (tasks.isEmpty) {
                return Center(
                  child: Text(
                    l.tagEmpty,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskRow(task: task, db: db);
                },
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 50),
                itemCount: tasks.length,
              );
            },
          ),
        );
      },
    );
  }
}
