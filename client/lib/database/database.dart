import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
  
  // --- Task DAO Methods ---

  // 获取所有未删除的任务
  Future<List<Task>> getAllTasks() => select(tasks).get();
  
  // 获取今天的任务 (示例：简单的日期过滤)
  // 实际场景可能需要更复杂的日期比较逻辑
  Stream<List<Task>> watchTodayTasks() {
    return (select(tasks)
      ..where((t) => t.status.equals(0)) // 未完成
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
    ).watch();
  }

  // 收件箱任务：当前简单等同于“所有未完成任务”
  Stream<List<Task>> watchInboxTasks() {
    return (select(tasks)
      ..where((t) => t.status.equals(0))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
    ).watch();
  }

  // 指定日期的任务（根据 dueDate 落在当天范围内）
  Stream<List<Task>> watchTasksForDate(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return (select(tasks)
      ..where((t) => t.dueDate.isBetweenValues(start, end))
      ..orderBy([(t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)])
    ).watch();
  }

  Future<void> deleteTask(String id) async {
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value(2),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // 插入新任务
  Future<int> insertTask(TasksCompanion task) => into(tasks).insert(task);

  // 更新任务
  Future<bool> updateTask(Task task) => update(tasks).replace(task);
  
  // 切换任务完成状态
  Future<void> toggleTaskStatus(String id, bool isDone) async {
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(isDone ? 1 : 0),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'flowlog.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
