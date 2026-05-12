import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../task_sort.dart';
import '../widgets/task_row.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.sortMode = TaskSortMode.createdDesc,
  });

  final String projectId;
  final String projectName;
  final TaskSortMode sortMode;

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
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
      status: const drift.Value(0),
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
      projectId: drift.Value(widget.projectId),
      dueDate: const drift.Value(null),
    );

    db.insertTask(newTask);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final l = AppLocalizations.of(context);
    return StreamBuilder<Project?>(
      stream: db.watchProjectById(widget.projectId),
      builder: (context, snapshot) {
        final title = snapshot.data?.name ?? widget.projectName;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            centerTitle: true,
          ),
          body: LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            return Column(
              children: [
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
                            hintText: title,
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addTask(db),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Task>>(
                    stream: db.watchTasksByProject(widget.projectId),
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
                          child: Text(
                            l.projectEmpty,
                            style: TextStyle(color: Colors.grey[500]),
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
          }),
        );
      },
    );
  }
}
