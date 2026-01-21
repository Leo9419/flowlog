import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

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

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      
      return Column(
        children: [
          // Quick Add Bar (TickTick Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: const Border(bottom: BorderSide(color: Colors.black12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                )
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue),
                  onPressed: () => _addTask(db),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

                final tasks = snapshot.data!;
                
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

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskRow(task: task, db: db, isWide: isWide);
                  },
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 50),
                  itemCount: tasks.length,
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
