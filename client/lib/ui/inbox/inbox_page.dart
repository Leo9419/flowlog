import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';
import '../widgets/task_list_container.dart';
import '../task_sort.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final TaskSortMode sortMode;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTask(AppDatabase db) {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final newTask = TasksCompanion(
      id: drift.Value(const Uuid().v4()),
      title: drift.Value(title),
      status: const drift.Value(0), // Todo
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
      // Inbox tasks usually have no due date by default
      dueDate: const drift.Value(null), 
    );

    db.insertTask(newTask);
    _controller.clear();
    // Keep focus to continue adding
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quickAddShadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      
      return Column(
        children: [
          // Quick Add Bar (TickTick Style)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
              boxShadow: quickAddShadow,
            ),
            child: Row(
              children: [
                Material(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _addTask(db),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: l.inboxTaskTitle,
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                    onSubmitted: (_) => _addTask(db),
                  ),
                ),
              ],
            ),
          ),
          
          // Task List
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: db.watchInboxTasks(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = sortTasks(snapshot.data!, widget.sortMode);
                
                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(l.inboxTaskTitle, style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return TaskListContainer(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskRow(task: task, db: db, isWide: isWide);
                    },
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 50),
                    itemCount: tasks.length,
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
