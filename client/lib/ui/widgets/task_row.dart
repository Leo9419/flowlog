import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import '../../database/database.dart';

class TaskRow extends StatelessWidget {
  final Task task;
  final AppDatabase db;
  final bool isWide;

  const TaskRow({
    super.key,
    required this.task,
    required this.db,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 1;

    return GestureDetector(
      onSecondaryTapUp: (details) {
        showMenu(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: const [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                   db.deleteTask(task.id);
                });
              },
            ),
            PopupMenuItem(
              child: const Text('Priority'),
              enabled: false,
            ),
             PopupMenuItem(
              value: 'p3',
              child: Row(
                children: const [
                   Icon(Icons.flag, color: Colors.red, size: 20),
                   SizedBox(width: 8),
                   Text('High'),
                ],
              ),
               onTap: () {
                  (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
                    TasksCompanion(priority: const drift.Value(3))
                  );
               },
            ),
             PopupMenuItem(
              value: 'p2',
              child: Row(
                children: const [
                   Icon(Icons.flag, color: Colors.orange, size: 20),
                   SizedBox(width: 8),
                   Text('Medium'),
                ],
              ),
               onTap: () {
                  (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
                    TasksCompanion(priority: const drift.Value(2))
                  );
               },
            ),
             PopupMenuItem(
              value: 'p1',
              child: Row(
                children: const [
                   Icon(Icons.flag, color: Colors.blue, size: 20),
                   SizedBox(width: 8),
                   Text('Low'),
                ],
              ),
               onTap: () {
                  (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
                    TasksCompanion(priority: const drift.Value(1))
                  );
               },
            ),
             PopupMenuItem(
              value: 'p0',
              child: Row(
                children: const [
                   Icon(Icons.flag_outlined, color: Colors.grey, size: 20),
                   SizedBox(width: 8),
                   Text('None'),
                ],
              ),
               onTap: () {
                  (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
                    TasksCompanion(priority: const drift.Value(0))
                  );
               },
            ),
          ],
        );
      },
      child: InkWell(
        onTap: () {
          // TODO: Open detail
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
          ),
          child: Row(
            children: [
              // Checkbox (Priority Colored)
              InkWell(
                onTap: () {
                  db.toggleTaskStatus(task.id, !isDone);
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDone ? Colors.grey : _getPriorityColor(task.priority),
                      width: 2,
                    ),
                    color: isDone ? Colors.grey.withOpacity(0.2) : Colors.transparent,
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? Colors.grey : Colors.black87,
                      ),
                    ),
                    // Due Date if exists
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: _getDueDateColor(task.dueDate!)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(task.dueDate!), 
                            style: TextStyle(fontSize: 12, color: _getDueDateColor(task.dueDate!)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Desktop: Show more details on the right
              if (isWide) ...[
                const SizedBox(width: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(int? priority) {
    switch (priority) {
      case 3: return Colors.red;
      case 2: return Colors.orange;
      case 1: return Colors.blue;
      default: return Colors.grey;
    }
  }

  Color _getDueDateColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate.isBefore(today)) {
      return Colors.red; // Overdue
    } else if (taskDate.isAtSameMomentAs(today)) {
      return Colors.blue; // Today
    } else {
      return Colors.grey; // Future
    }
  }

  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}";
  }
}
