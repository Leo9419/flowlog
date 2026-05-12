import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: trashLeadingWidthForPlatform(defaultTargetPlatform),
        title: Text(l.trash),
      ),
      body: StreamBuilder<List<Task>>(
        stream: db.watchDeletedTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                l.trashEmpty,
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final dueDate = task.dueDate;
              final subtitle = dueDate == null
                  ? l.noDueDate
                  : '${dueDate.month}/${dueDate.day}';

              return ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(task.title),
                subtitle: Text(subtitle),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => db.restoreTask(task.id),
                      child: Text(l.restore),
                    ),
                    IconButton(
                      onPressed: () => db.permanentlyDeleteTask(task.id),
                      icon: const Icon(Icons.delete_forever_outlined),
                      tooltip: l.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemCount: tasks.length,
          );
        },
      ),
    );
  }
}

@visibleForTesting
double? trashLeadingWidthForPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.macOS ? 88 : null;
}
