import '../database/database.dart';

enum TaskSortMode {
  createdDesc,
  dueDateAsc,
  priorityDesc,
}

List<Task> sortTasks(List<Task> tasks, TaskSortMode mode) {
  final sorted = List<Task>.from(tasks);
  switch (mode) {
    case TaskSortMode.createdDesc:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case TaskSortMode.dueDateAsc:
      sorted.sort((a, b) {
        final aDate = a.dueDate ?? a.endDate;
        final bDate = b.dueDate ?? b.endDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      break;
    case TaskSortMode.priorityDesc:
      sorted.sort((a, b) => b.priority.compareTo(a.priority));
      break;
  }
  return sorted;
}
