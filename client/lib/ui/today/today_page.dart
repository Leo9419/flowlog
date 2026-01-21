import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';

import '../widgets/task_row.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
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
      // 简单起见，暂不设置 dueDate，默认逻辑上它出现在“今天”是因为它是新加的
      // 实际逻辑应该设置 dueDate 为今天
      dueDate: drift.Value(DateTime.now()), 
    );

    db.insertTask(newTask);
    _controller.clear();
    // 保持焦点以便继续输入
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
          // 快速添加栏
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
                      hintText: l.addTaskToToday,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTask(db),
                  ),
                ),
              ],
            ),
          ),
          
          // 任务列表
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: db.watchTodayTasks(),
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
                        Icon(Icons.wb_sunny_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(l.todayEmpty, style: TextStyle(color: Colors.grey[500])),
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
