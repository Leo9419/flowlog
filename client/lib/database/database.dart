import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:uuid/uuid.dart';
import 'tables.dart';

part 'database.g.dart';

/// Tasks.whenType 枚举映射。
///
/// 与 SQL 中存储的整数一一对应，UI 层通过 [WhenType.fromInt] / `.value`
/// 在两端转换。状态语义见 `M1_01_Data_Model.md` §3.1。
enum WhenType {
  none(0),
  today(1),
  thisEvening(2),
  someday(3),
  scheduled(4);

  const WhenType(this.value);
  final int value;

  static WhenType fromInt(int value) =>
      WhenType.values.firstWhere((w) => w.value == value, orElse: () => none);
}

/// Today 视图三段式分组：morning / evening / overdue。
class TodaySections {
  const TodaySections({
    required this.morning,
    required this.evening,
    required this.overdue,
  });

  final List<Task> morning;
  final List<Task> evening;
  final List<Task> overdue;
}

/// 项目进度环用：完成任务数 / 总任务数。
class ProjectProgress {
  const ProjectProgress({required this.done, required this.total});
  final int done;
  final int total;
}

@DriftDatabase(
  tables: [
    Tasks,
    Projects,
    Tags,
    TaskTags,
    Areas,
    Headings,
    Checklists,
    AiSuggestions,
    AiActionLog,
    AiConversations,
    AiMessages,
    AiCoachInsights,
    AiSuggestionRules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试专用构造器：注入自定义 [QueryExecutor]（通常是 in-memory
  /// NativeDatabase 包裹一个手工建好 v8 schema 的 raw sqlite 连接），
  /// 用于触发 onUpgrade 路径而不依赖 path_provider。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

  // Drift uses `migration`; keep `migrations` as a compatibility alias.
  MigrationStrategy get migrations => migration;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createAiIndexes();
          await _seedDefaultProjects();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(projects);
            await m.createTable(tags);
            await m.createTable(taskTags);
            await _seedDefaultProjects();
          }
          if (from < 3) {
            await m.addColumn(tasks, tasks.repeatRule);
            await m.addColumn(tasks, tasks.repeatMode);
            await m.addColumn(tasks, tasks.repeatUntil);
          }
          if (from < 5) {
            await _normalizeLegacyDateTimes();
          }
          if (from < 6) {
            await m.addColumn(tasks, tasks.parentId);
          }
          if (from >= 2 && from < 7) {
            await m.addColumn(tags, tags.sortOrder);
            final existing = await (select(tags)
                  ..orderBy([(t) => OrderingTerm(expression: t.name)]))
                .get();
            await batch((batch) {
              for (var i = 0; i < existing.length; i++) {
                batch.update(
                  tags,
                  TagsCompanion(sortOrder: Value(i)),
                  where: (t) => t.id.equals(existing[i].id),
                );
              }
            });
          }
          if (from < 8) {
            await m.addColumn(tasks, tasks.endDate);
          }
          if (from < 9) {
            await _migrateToThingsAlignment(m);
          }
          if (from < 10) {
            await _createAiTables(m);
          }
        },
        beforeOpen: (details) async {
          await _normalizeLegacyDateTimes();
        },
      );

  Future<void> _createAiTables(Migrator m) async {
    await m.createTable(aiSuggestions);
    await m.createTable(aiActionLog);
    await m.createTable(aiConversations);
    await m.createTable(aiMessages);
    await m.createTable(aiCoachInsights);
    await m.createTable(aiSuggestionRules);
    await _createAiIndexes();
  }

  Future<void> _createAiIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_suggestions_status_created_at '
      'ON ai_suggestions(status, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ai_suggestions_surface_status '
      'ON ai_suggestions(surface, status)',
    );
  }

  /// v8 → v9：Things 对齐迁移。
  ///
  /// 1. 新增 Areas / Headings / Checklists 三张表。
  /// 2. Tasks：serverId Int → Text（rebuild 表），加 notes / whenType /
  ///    deadline / reminderAt / evening / headingId / sortOrder / inLogbook。
  /// 3. Projects：color Int 非空 → Text nullable（hex），加 serverId /
  ///    iconName / notes / areaId / whenType / deadline / status /
  ///    completedAt / sortOrder。
  /// 4. 数据回填：notes ← content；whenType ← dueDate；sortOrder 按
  ///    createdAt 顺序在每个 project 内重置。
  Future<void> _migrateToThingsAlignment(Migrator m) async {
    // 新表先建，避免后续 alterTable 触发的 PRAGMA writable_schema 期间还要新增。
    await m.createTable(areas);
    await m.createTable(headings);
    await m.createTable(checklists);

    // 探测当前 schema 形态：from<2 升级路径用的是 m.createTable(projects)，
    // 它直接按 Dart 当前定义建表，所以 v1 用户进到这里时 projects 已经是 v9
    // 形态；这种情况不能再当 v8 做 TableMigration（会用 printf 把已有的
    // hex 字符串当 int 解析、把 color 写成 '#00000000'，并会重复添加列）。
    // tasks 在 v1 就存在且历史从未 createTable，所以都会到达这里。
    final taskCols = await _columnsOf('tasks');
    final projectCols = await _columnsOf('projects');
    final tasksAlreadyV9 = taskCols.contains('notes');
    final projectsAlreadyV9 = projectCols.contains('notes');

    if (!tasksAlreadyV9) {
      // Tasks 表 rebuild：serverId 类型变更 + 8 个新列。
      // CAST(server_id AS TEXT)：旧值是 INTEGER，转成对应的十进制字符串；
      // NULL 自动保持 NULL。
      await m.alterTable(
        TableMigration(
          tasks,
          columnTransformer: {
            tasks.serverId: const CustomExpression<String>(
              'CAST(server_id AS TEXT)',
              precedence: Precedence.primary,
            ),
          },
          newColumns: [
            tasks.notes,
            tasks.whenType,
            tasks.deadline,
            tasks.reminderAt,
            tasks.evening,
            tasks.headingId,
            tasks.sortOrder,
            tasks.inLogbook,
          ],
        ),
      );
    }

    if (!projectsAlreadyV9) {
      // Projects 表 rebuild：color 类型变更 + 10 个新列（含 isDirty —— 旧 v8
      // projects 没有这列，本次新加）。
      // printf('#%08X', color)：把 32-bit ARGB int 转为 '#AARRGGBB' 大写字符串。
      await m.alterTable(
        TableMigration(
          projects,
          columnTransformer: {
            projects.color: const CustomExpression<String>(
              "printf('#%08X', color)",
              precedence: Precedence.primary,
            ),
          },
          newColumns: [
            projects.serverId,
            projects.iconName,
            projects.notes,
            projects.areaId,
            projects.whenType,
            projects.deadline,
            projects.status,
            projects.completedAt,
            projects.sortOrder,
            projects.isDirty,
          ],
        ),
      );
    }

    // 回填 notes：旧的 content 文本搬到 notes（不删 content，留作 M2 兼容窗口）。
    // 仅当确实经历了 v8→v9 rebuild 时才有意义；v1→v9 路径里 tasks 一开始
    // 就有 notes 列且默认 ''，content 在 v1 schema 里也存在（从未删除），
    // 所以无论哪条路径执行此 UPDATE 都安全。
    await customStatement(
      "UPDATE tasks SET notes = COALESCE(content, '') WHERE notes = ''",
    );

    // 回填 whenType：
    //   * dueDate 为空 → 0 (none)，进 Inbox/Anytime
    //   * dueDate 是今天 → 1 (today)
    //   * dueDate 在过去或未来 → 4 (scheduled)，UI 自行判定逾期
    //
    // Drift 2.30+ 默认把 DateTime 存为 unix seconds（millisecondsSinceEpoch
    // ~/ 1000），可直接喂给 sqlite 的 'unixepoch' modifier，无需再 /1000。
    await customStatement('''
      UPDATE tasks SET when_type = CASE
        WHEN due_date IS NULL THEN 0
        WHEN date(due_date, 'unixepoch', 'localtime') = date('now', 'localtime') THEN 1
        ELSE 4
      END
    ''');

    // 回填 sortOrder：每个 project 内按 createdAt 顺序重排（NULL projectId 视作 inbox）。
    await customStatement('''
      UPDATE tasks SET sort_order = (
        SELECT COUNT(*) FROM tasks t2
        WHERE COALESCE(t2.project_id, '') = COALESCE(tasks.project_id, '')
          AND t2.created_at < tasks.created_at
      )
    ''');
  }

  // --- Task DAO Methods ---

  // 获取所有未删除的任务
  Future<List<Task>> getAllTasks() => select(tasks).get();

  // 获取今天的任务 (示例：简单的日期过滤)
  // 实际场景可能需要更复杂的日期比较逻辑
  Stream<List<Task>> watchTodayTasks() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return (select(tasks)
          ..where((t) =>
              (t.status.isIn([0, 1]) & t.dueDate.isBetweenValues(start, end)) |
              (t.status.equals(0) & t.dueDate.isSmallerThanValue(start)))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  // 收件箱任务：当前简单等同于“所有未完成任务”
  Stream<List<Task>> watchInboxTasks() {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.dueDate.isNull() &
              t.endDate.isNull() &
              t.projectId.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)
          ..where((t) => t.status.isIn([0, 1]) & t.parentId.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<List<Task>> fetchTasksForSummary() {
    return (select(tasks)
          ..where((t) => t.status.isIn([0, 1]) & t.parentId.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Stream<List<Task>> watchUpcomingTasks() {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.dueDate.isBiggerOrEqualValue(start))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Stream<List<Task>> watchPlanTasks() {
    return (select(tasks)
          ..where((t) =>
              t.status.isIn([0, 1]) &
              t.parentId.isNull() &
              (t.dueDate.isNotNull() | t.endDate.isNotNull()))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Stream<List<Task>> watchNotifiableTasks() {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              (t.dueDate.isNotNull() | t.endDate.isNotNull()))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Stream<List<Task>> watchSubtasks(String parentId) {
    return (select(tasks)
          ..where((t) => t.parentId.equals(parentId) & t.status.isIn([0, 1]))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Stream<List<Task>> watchTasksByProject(String projectId) {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.projectId.equals(projectId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Stream<List<Task>> watchActiveTasks() {
    return (select(tasks)
          ..where((t) => t.status.isIn([0, 1]))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  // 指定日期的任务（根据 dueDate 落在当天范围内）
  Stream<List<Task>> watchTasksForDate(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return (select(tasks)
          ..where((t) =>
              t.dueDate.isBetweenValues(start, end) &
              t.status.isIn([0, 1]) &
              t.parentId.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  // 已删除任务
  Stream<List<Task>> watchDeletedTasks() {
    return (select(tasks)
          ..where((t) => t.status.equals(2) & t.parentId.isNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  // 搜索任务（标题匹配）
  Stream<List<Task>> watchTasksByKeyword(String keyword) {
    final query = keyword.trim();
    if (query.isEmpty) {
      return const Stream.empty();
    }
    final pattern = '%$query%';
    return (select(tasks)
          ..where((t) =>
              t.status.isIn([0, 1]) &
              t.parentId.isNull() &
              t.title.like(pattern))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<List<Task>> searchTasksForChat(String keyword,
      {int limit = 20}) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return recentTasksForChat(limit: limit);
    }
    final pattern = '%$query%';
    return (select(tasks)
          ..where((t) =>
              t.status.isIn([0, 1]) &
              (t.title.like(pattern) | t.content.like(pattern)))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }

  Future<List<Task>> recentTasksForChat({int limit = 20}) {
    return (select(tasks)
          ..where((t) => t.status.isIn([0, 1]))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }

  Future<void> deleteTask(String id) async {
    final parentId = await _getParentId(id);
    await transaction(() async {
      await (update(tasks)
            ..where((t) => t.id.equals(id) | t.parentId.equals(id)))
          .write(
        TasksCompanion(
          status: const Value(2),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
    if (parentId != null) {
      await _syncParentStatus(parentId);
    }
  }

  // 插入新任务
  Future<int> insertTask(TasksCompanion task) async {
    final now = DateTime.now();
    final companion = task.copyWith(
      createdAt: task.createdAt.present ? task.createdAt : Value(now),
      updatedAt: task.updatedAt.present ? task.updatedAt : Value(now),
    );
    final id = await into(tasks).insert(companion);
    final parentId = task.parentId.present ? task.parentId.value : null;
    if (parentId != null) {
      await _markParentIncomplete(parentId);
    }
    return id;
  }

  // 更新任务
  Future<bool> updateTask(Task task) => update(tasks).replace(task);

  // 切换任务完成状态
  Future<void> toggleTaskStatus(String id, bool isDone) async {
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(isDone ? 1 : 0),
        completedAt: Value(isDone ? DateTime.now() : null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    final parentId = await _getParentId(id);
    if (parentId != null) {
      await _syncParentStatus(parentId);
    }
  }

  Future<String?> _getParentId(String taskId) async {
    final task = await (select(tasks)..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    return task?.parentId;
  }

  Future<void> _markParentIncomplete(String parentId) async {
    final parent = await (select(tasks)..where((t) => t.id.equals(parentId)))
        .getSingleOrNull();
    if (parent == null || parent.status != 1) return;
    await (update(tasks)..where((t) => t.id.equals(parentId))).write(
      TasksCompanion(
        status: const Value(0),
        completedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _syncParentStatus(String parentId) async {
    final subtasks = await (select(tasks)
          ..where(
            (t) => t.parentId.equals(parentId) & t.status.isIn([0, 1]),
          ))
        .get();
    if (subtasks.isEmpty) return;
    final allDone = subtasks.every((task) => task.status == 1);
    final desiredStatus = allDone ? 1 : 0;
    final parent = await (select(tasks)..where((t) => t.id.equals(parentId)))
        .getSingleOrNull();
    if (parent == null ||
        parent.status == 2 ||
        parent.status == desiredStatus) {
      return;
    }
    await (update(tasks)..where((t) => t.id.equals(parentId))).write(
      TasksCompanion(
        status: Value(desiredStatus),
        completedAt: Value(allDone ? DateTime.now() : null),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreTask(String id) async {
    await transaction(() async {
      await (update(tasks)
            ..where((t) => t.id.equals(id) | t.parentId.equals(id)))
          .write(
        TasksCompanion(
          status: const Value(0),
          completedAt: const Value(null),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> permanentlyDeleteTask(String id) async {
    await transaction(() async {
      final taskRows = await (select(tasks)
            ..where((t) => t.id.equals(id) | t.parentId.equals(id)))
          .get();
      final taskIds = taskRows.map((task) => task.id).toList();
      if (taskIds.isEmpty) return;

      await (delete(taskTags)..where((t) => t.taskId.isIn(taskIds))).go();
      await (delete(tasks)..where((t) => t.id.isIn(taskIds))).go();
    });
  }

  Stream<List<Project>> watchProjects() {
    return (select(projects)
          ..orderBy([(p) => OrderingTerm(expression: p.name)]))
        .watch();
  }

  Stream<Project?> watchProjectById(String projectId) {
    return (select(projects)..where((p) => p.id.equals(projectId)))
        .watchSingleOrNull();
  }

  /// 创建项目。
  ///
  /// [color] 是 `#AARRGGBB` 字符串（用 `colorToHex` 生成）；传 null 表示沿用
  /// 主题默认色。
  Future<String> createProject(String name, String? color) async {
    final id = const Uuid().v4();
    await into(projects).insert(
      ProjectsCompanion(
        id: Value(id),
        name: Value(name),
        color: Value(color),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  Future<void> updateProject(String id, String name, String? color) async {
    await (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name),
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteProject(String id) async {
    await transaction(() async {
      await (update(tasks)..where((t) => t.projectId.equals(id))).write(
        TasksCompanion(
          projectId: const Value(null),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (delete(projects)..where((p) => p.id.equals(id))).go();
    });
  }

  Stream<List<Tag>> watchTags() {
    return (select(tags)
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  Stream<Tag?> watchTagById(String tagId) {
    return (select(tags)..where((t) => t.id.equals(tagId))).watchSingleOrNull();
  }

  Future<String> createTag(String name, int color) async {
    final id = const Uuid().v4();
    final maxOrderExp = tags.sortOrder.max();
    final row = await (selectOnly(tags)..addColumns([maxOrderExp])).getSingle();
    final maxOrder = row.read(maxOrderExp) ?? -1;
    await into(tags).insert(
      TagsCompanion(
        id: Value(id),
        name: Value(name),
        color: Value(color),
        sortOrder: Value(maxOrder + 1),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  Future<void> updateTag(String id, String name, int color) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: Value(name),
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteTag(String id) async {
    await transaction(() async {
      await (delete(taskTags)..where((t) => t.tagId.equals(id))).go();
      await (delete(tags)..where((t) => t.id.equals(id))).go();
    });
  }

  Stream<List<Tag>> watchTagsForTask(String taskId) {
    final query = select(tags).join(
      [
        innerJoin(taskTags, taskTags.tagId.equalsExp(tags.id)),
      ],
    )
      ..where(taskTags.taskId.equals(taskId))
      ..orderBy([
        OrderingTerm(expression: tags.sortOrder),
        OrderingTerm(expression: tags.name),
      ]);

    return query
        .watch()
        .map((rows) => rows.map((row) => row.readTable(tags)).toList());
  }

  Future<List<Tag>> getTagsForTask(String taskId) async {
    final query = select(tags).join(
      [
        innerJoin(taskTags, taskTags.tagId.equalsExp(tags.id)),
      ],
    )..where(taskTags.taskId.equals(taskId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList();
  }

  Future<void> updateTagSortOrders(List<String> orderedIds) async {
    await batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          tags,
          TagsCompanion(sortOrder: Value(i), updatedAt: Value(DateTime.now())),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Stream<List<Task>> watchTasksByTag(String tagId) {
    final query = select(tasks).join(
      [
        innerJoin(taskTags, taskTags.taskId.equalsExp(tasks.id)),
      ],
    )
      ..where(taskTags.tagId.equals(tagId) &
          tasks.status.isIn([0, 1]) &
          tasks.parentId.isNull())
      ..orderBy(
          [OrderingTerm(expression: tasks.updatedAt, mode: OrderingMode.desc)]);

    return query
        .watch()
        .map((rows) => rows.map((row) => row.readTable(tasks)).toList());
  }

  Future<Set<String>> getTagIdsForTask(String taskId) async {
    final rows =
        await (select(taskTags)..where((t) => t.taskId.equals(taskId))).get();
    return rows.map((row) => row.tagId).toSet();
  }

  Future<void> setTagsForTask(String taskId, Set<String> tagIds) async {
    await transaction(() async {
      await (delete(taskTags)..where((t) => t.taskId.equals(taskId))).go();
      if (tagIds.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            taskTags,
            tagIds
                .map((tagId) =>
                    TaskTagsCompanion.insert(taskId: taskId, tagId: tagId))
                .toList(),
          );
        });
      }
      await (update(tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // ==========================================================================
  // M1_01：Things 对齐后的查询 / 写入 API
  // --------------------------------------------------------------------------
  // 旧 watchTodayTasks / watchInboxTasks 等保留至 M2 视图重构完成；新视图（Today
  // 含 Evening 分组、Anytime / Someday / Logbook）走下面这一组。
  // ==========================================================================

  /// Today 视图三段式：
  ///   * morning：whenType=today 且 evening=false，或 whenType=scheduled 且 dueDate=今天
  ///   * evening：whenType=thisEvening 或 evening=true
  ///   * overdue：status=Todo 且 dueDate<今天
  ///
  /// 用单个 watch 流取所有命中行后在 Dart 端分组，避免多 stream 合并依赖。
  Stream<TodaySections> watchTodayWithEvening() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));

    return (select(tasks)
          ..where((t) =>
              t.parentId.isNull() &
              t.status.equals(0) &
              (t.whenType.equals(WhenType.today.value) |
                  t.whenType.equals(WhenType.thisEvening.value) |
                  (t.whenType.equals(WhenType.scheduled.value) &
                      t.dueDate
                          .isBetweenValues(startOfToday, startOfTomorrow)) |
                  (t.dueDate.isNotNull() &
                      t.dueDate.isSmallerThanValue(startOfToday))))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) {
      final morning = <Task>[];
      final evening = <Task>[];
      final overdue = <Task>[];
      for (final t in rows) {
        final due = t.dueDate;
        if (due != null && due.isBefore(startOfToday)) {
          overdue.add(t);
        } else if (t.evening || t.whenType == WhenType.thisEvening.value) {
          evening.add(t);
        } else {
          morning.add(t);
        }
      }
      return TodaySections(
          morning: morning, evening: evening, overdue: overdue);
    });
  }

  /// Anytime 视图：未安排（whenType=none/scheduled）但不在 Someday 的活动任务。
  Stream<List<Task>> watchAnytimeTasks() {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.whenType.isIn([WhenType.none.value, WhenType.scheduled.value]))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Someday 视图：whenType=someday。
  ///
  /// M2 才会真正用到；M1 阶段 Sidebar 的"将来"项已切换到
  /// [watchFutureTasks]（dueDate 严格未来），所以本方法目前是占位接口。
  Stream<List<Task>> watchSomedayTasks() {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.whenType.equals(WhenType.someday.value))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// "将来"视图：dueDate 严格在明天 0 点及以后的活动任务。
  ///
  /// 与 Calendar（Upcoming）的区别：Calendar 是按日期分组的视觉化布局
  /// （含今天 / 过去 7 天 / 月分组），这里是单纯的"未来任务"扁平列表，
  /// 按 dueDate 升序排，不区分天数粒度。
  Stream<List<Task>> watchFutureTasks() {
    final now = DateTime.now();
    final startOfTomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.dueDate.isNotNull() &
              t.dueDate.isBiggerOrEqualValue(startOfTomorrow))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
            (t) => OrderingTerm(expression: t.sortOrder),
          ]))
        .watch();
  }

  /// Logbook 视图：已完成且 inLogbook=true 的任务，按完成时间降序。
  ///
  /// [days] 默认 90 天；UI 滚动时可加大窗口。
  Stream<List<Task>> watchLogbook({int days = 90}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(tasks)
          ..where((t) =>
              t.status.equals(1) &
              t.inLogbook.equals(true) &
              t.completedAt.isBiggerThanValue(cutoff))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.completedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<Area>> watchAreas() {
    return (select(areas)
          ..orderBy([
            (a) => OrderingTerm(expression: a.sortOrder),
            (a) => OrderingTerm(expression: a.name),
          ]))
        .watch();
  }

  /// 列出某个 Area 下的项目；[areaId] 为 null 时返回未归属任何 Area 的项目。
  Stream<List<Project>> watchProjectsByArea(String? areaId) {
    final query = select(projects)
      ..where((p) =>
          p.status.equals(0) &
          (areaId == null ? p.areaId.isNull() : p.areaId.equals(areaId)))
      ..orderBy([
        (p) => OrderingTerm(expression: p.sortOrder),
        (p) => OrderingTerm(expression: p.name),
      ]);
    return query.watch();
  }

  Stream<List<Heading>> watchHeadings(String projectId) {
    return (select(headings)
          ..where((h) => h.projectId.equals(projectId) & h.archivedAt.isNull())
          ..orderBy([
            (h) => OrderingTerm(expression: h.sortOrder),
            (h) => OrderingTerm(expression: h.createdAt),
          ]))
        .watch();
  }

  Stream<List<Checklist>> watchChecklist(String taskId) {
    return (select(checklists)
          ..where((c) => c.taskId.equals(taskId))
          ..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.createdAt),
          ]))
        .watch();
  }

  /// 项目进度：未删除任务的 done / total。完成 / 取消 / 删除状态分别为 1 / 2 / 2，
  /// 这里仅统计 status IN (0, 1)。
  Stream<ProjectProgress> watchProjectProgress(String projectId) {
    return (select(tasks)
          ..where((t) =>
              t.projectId.equals(projectId) &
              t.parentId.isNull() &
              t.status.isIn([0, 1])))
        .watch()
        .map((rows) {
      final total = rows.length;
      final done = rows.where((r) => r.status == 1).length;
      return ProjectProgress(done: done, total: total);
    });
  }

  Stream<List<Task>> watchTasksByHeading(String headingId) {
    return (select(tasks)
          ..where((t) =>
              t.status.equals(0) &
              t.parentId.isNull() &
              t.headingId.equals(headingId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  // ── 写入 API ───────────────────────────────────────────────────────────

  /// 同时维护 whenType 与 dueDate / evening。
  ///
  ///   * [WhenType.today] / [WhenType.thisEvening]：dueDate 自动设为当天 00:00
  ///   * [WhenType.scheduled]：必须传 [date]；否则等同于 [WhenType.none]
  ///   * 其他：dueDate 清空
  Future<void> setTaskWhen(
    String taskId,
    WhenType when, {
    DateTime? date,
  }) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    DateTime? newDue;
    bool evening = false;
    var actualWhen = when;

    switch (when) {
      case WhenType.none:
      case WhenType.someday:
        newDue = null;
        break;
      case WhenType.today:
        newDue = startOfToday;
        break;
      case WhenType.thisEvening:
        newDue = startOfToday;
        evening = true;
        break;
      case WhenType.scheduled:
        if (date == null) {
          actualWhen = WhenType.none;
          newDue = null;
        } else {
          newDue = DateTime(date.year, date.month, date.day);
        }
        break;
    }

    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        whenType: Value(actualWhen.value),
        dueDate: Value(newDue),
        evening: Value(evening),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setTaskDeadline(String taskId, DateTime? deadline) async {
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        deadline: Value(deadline),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 仅写库；调度本地通知由调用方拿到结果后调用 NotificationService。
  Future<void> setTaskReminder(String taskId, DateTime? reminderAt) async {
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        reminderAt: Value(reminderAt),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 移动任务到指定项目（或 null = 取消归属）；可选指定 heading。
  /// 在同一事务内重排目标项目内的 sortOrder，新任务排到末尾。
  Future<void> moveTaskToProject(
    String taskId,
    String? projectId, {
    String? headingId,
  }) async {
    await transaction(() async {
      final maxExp = tasks.sortOrder.max();
      final row = await (selectOnly(tasks)
            ..addColumns([maxExp])
            ..where(projectId == null
                ? tasks.projectId.isNull()
                : tasks.projectId.equals(projectId)))
          .getSingleOrNull();
      final maxOrder = row?.read(maxExp) ?? -1;

      await (update(tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          projectId: Value(projectId),
          headingId: Value(headingId),
          sortOrder: Value(maxOrder + 1),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// 拖拽排序：按 [orderedIds] 顺序把 sortOrder 重写为 0,1,2,...
  /// 调用方应保证这些 ID 属于同一个分组（同 project / heading / view）。
  Future<void> reorderTasks(List<String> orderedIds) async {
    final now = DateTime.now();
    await batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          tasks,
          TasksCompanion(
            sortOrder: Value(i),
            isDirty: const Value(true),
            updatedAt: Value(now),
          ),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // ── Checklist CRUD ─────────────────────────────────────────────────────

  Future<String> insertChecklistItem(String taskId, String title) async {
    final id = const Uuid().v4();
    final maxExp = checklists.sortOrder.max();
    final row = await (selectOnly(checklists)
          ..addColumns([maxExp])
          ..where(checklists.taskId.equals(taskId)))
        .getSingleOrNull();
    final maxOrder = row?.read(maxExp) ?? -1;
    await into(checklists).insert(
      ChecklistsCompanion(
        id: Value(id),
        taskId: Value(taskId),
        title: Value(title),
        sortOrder: Value(maxOrder + 1),
      ),
    );
    return id;
  }

  Future<void> toggleChecklistItem(String id, bool isChecked) async {
    await (update(checklists)..where((c) => c.id.equals(id))).write(
      ChecklistsCompanion(
        isChecked: Value(isChecked),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorderChecklist(List<String> orderedIds) async {
    final now = DateTime.now();
    await batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          checklists,
          ChecklistsCompanion(
            sortOrder: Value(i),
            isDirty: const Value(true),
            updatedAt: Value(now),
          ),
          where: (c) => c.id.equals(orderedIds[i]),
        );
      }
    });
  }

  Future<void> deleteChecklistItem(String id) async {
    await (delete(checklists)..where((c) => c.id.equals(id))).go();
  }

  // ── Heading CRUD ───────────────────────────────────────────────────────

  Future<String> insertHeading(String projectId, String title) async {
    final id = const Uuid().v4();
    final maxExp = headings.sortOrder.max();
    final row = await (selectOnly(headings)
          ..addColumns([maxExp])
          ..where(headings.projectId.equals(projectId)))
        .getSingleOrNull();
    final maxOrder = row?.read(maxExp) ?? -1;
    await into(headings).insert(
      HeadingsCompanion(
        id: Value(id),
        projectId: Value(projectId),
        title: Value(title),
        sortOrder: Value(maxOrder + 1),
      ),
    );
    return id;
  }

  Future<void> archiveHeading(String id) async {
    await (update(headings)..where((h) => h.id.equals(id))).write(
      HeadingsCompanion(
        archivedAt: Value(DateTime.now()),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reorderHeadings(List<String> orderedIds) async {
    final now = DateTime.now();
    await batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          headings,
          HeadingsCompanion(
            sortOrder: Value(i),
            isDirty: const Value(true),
            updatedAt: Value(now),
          ),
          where: (h) => h.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // ── Area CRUD ──────────────────────────────────────────────────────────

  Future<String> insertArea(String name, {String? iconName}) async {
    final id = const Uuid().v4();
    final maxExp = areas.sortOrder.max();
    final row =
        await (selectOnly(areas)..addColumns([maxExp])).getSingleOrNull();
    final maxOrder = row?.read(maxExp) ?? -1;
    await into(areas).insert(
      AreasCompanion(
        id: Value(id),
        name: Value(name),
        iconName: Value(iconName),
        sortOrder: Value(maxOrder + 1),
      ),
    );
    return id;
  }

  Future<void> reorderAreas(List<String> orderedIds) async {
    final now = DateTime.now();
    await batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          areas,
          AreasCompanion(
            sortOrder: Value(i),
            isDirty: const Value(true),
            updatedAt: Value(now),
          ),
          where: (a) => a.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // ── AI persistence ─────────────────────────────────────────────────────

  Future<String> ensureAiConversation({
    String? id,
    required String title,
    String contextJson = '{}',
  }) async {
    final conversationId = id ?? const Uuid().v4();
    final now = DateTime.now();
    await into(aiConversations).insert(
      AiConversationsCompanion(
        id: Value(conversationId),
        title: Value(title.trim().isEmpty ? 'New chat' : title.trim()),
        contextJson: Value(contextJson),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return conversationId;
  }

  Stream<List<AiConversation>> watchAiConversations() {
    return (select(aiConversations)
          ..orderBy([
            (c) => OrderingTerm(expression: c.pinned, mode: OrderingMode.desc),
            (c) =>
                OrderingTerm(expression: c.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<AiMessage>> watchAiMessages(String conversationId) {
    return (select(aiMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm(expression: m.createdAt)]))
        .watch();
  }

  Future<String> insertAiMessage({
    required String conversationId,
    required String role,
    required String content,
    String? toolCallsJson,
    String? toolResultsJson,
    bool isError = false,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await transaction(() async {
      await into(aiMessages).insert(
        AiMessagesCompanion(
          id: Value(id),
          conversationId: Value(conversationId),
          role: Value(role),
          content: Value(content),
          toolCallsJson: Value(toolCallsJson),
          toolResultsJson: Value(toolResultsJson),
          isError: Value(isError),
          createdAt: Value(now),
        ),
      );
      await (update(aiConversations)..where((c) => c.id.equals(conversationId)))
          .write(AiConversationsCompanion(updatedAt: Value(now)));
    });
    return id;
  }

  Future<void> _seedDefaultProjects() async {
    final now = DateTime.now();
    // 历史值 4281559091 = 0xFF4287F5 (蓝)，4283215696 = 0xFF36AB10 (绿)
    await into(projects).insert(
      ProjectsCompanion(
        id: const Value('work'),
        name: const Value('Work'),
        color: const Value('#FF4287F5'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    await into(projects).insert(
      ProjectsCompanion(
        id: const Value('personal'),
        name: const Value('Personal'),
        color: const Value('#FF36AB10'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> _normalizeLegacyDateTimes() async {
    await _normalizeTableDateTimes(
        'projects', const ['created_at', 'updated_at']);
    await _normalizeTableDateTimes(
      'tasks',
      const [
        'created_at',
        'updated_at',
        'due_date',
        'end_date',
        'completed_at',
        'repeat_until'
      ],
    );
    await _normalizeTableDateTimes('tags', const ['created_at', 'updated_at']);
  }

  Future<void> _normalizeTableDateTimes(
      String table, List<String> columns) async {
    // v1–v4 升级路径会先调 normalize、再加新列（end_date / repeat_until 等），
    // 此时表里这些列还不存在；用 PRAGMA table_info 取实际列名集合做交集，
    // 避免 SQL 引用未存在的列让升级直接 hard-fail。
    final present = await _columnsOf(table);
    final usable = columns.where(present.contains).toList();
    if (usable.isEmpty) return;

    final assignments = usable
        .map(
          (column) => '''
        $column = CASE
          WHEN typeof($column) = 'text' THEN CAST(strftime('%s', $column) AS INTEGER)
          ELSE $column
        END''',
        )
        .join(',\n');

    await customStatement('''
      UPDATE $table
      SET
$assignments
    ''');
  }

  /// 用 PRAGMA table_info 取一张表的列名集合。表不存在时返回空集合。
  Future<Set<String>> _columnsOf(String table) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final appSupport = await getApplicationSupportDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final file = await resolveFlowLogDatabaseFileForTesting(
      appSupportDirectory: appSupport,
      documentsDirectory: documents,
      homeDirectory: Platform.environment['HOME'],
    );
    return NativeDatabase.createInBackground(file);
  });
}

Future<File> resolveFlowLogDatabaseFileForTesting({
  required Directory appSupportDirectory,
  required Directory documentsDirectory,
  required String? homeDirectory,
}) async {
  final targetDir = Directory(p.join(appSupportDirectory.path, 'FlowLog'));
  await targetDir.create(recursive: true);
  final target = File(p.join(targetDir.path, 'flowlog.sqlite'));
  final legacy = _legacyDatabaseCandidates(
    appSupportDirectory: appSupportDirectory,
    documentsDirectory: documentsDirectory,
    homeDirectory: homeDirectory,
  );
  legacy.sort((a, b) {
    final bModified = b.lastModifiedSync();
    final aModified = a.lastModifiedSync();
    return bModified.compareTo(aModified);
  });

  if (target.existsSync()) {
    if (await _shouldReplaceEmptyTarget(target, legacy)) {
      await target.copy('${target.path}.empty-backup');
      await _copySqliteDatabase(_bestLegacyDatabase(legacy), target);
    }
    return target;
  }

  if (legacy.isNotEmpty) {
    await _copySqliteDatabase(_bestLegacyDatabase(legacy), target);
  }
  return target;
}

List<File> _legacyDatabaseCandidates({
  required Directory appSupportDirectory,
  required Directory documentsDirectory,
  required String? homeDirectory,
}) {
  final paths = <String>{
    p.join(documentsDirectory.path, 'flowlog.sqlite'),
  };
  final home = _resolveHomeDirectory(
    homeDirectory: homeDirectory,
    appSupportDirectory: appSupportDirectory,
    documentsDirectory: documentsDirectory,
  );
  if (home != null) {
    paths.addAll([
      p.join(home, 'Documents', 'flowlog.sqlite'),
      p.join(
        home,
        'Library',
        'Containers',
        'com.example.flowlog',
        'Data',
        'Documents',
        'flowlog.sqlite',
      ),
      p.join(
        home,
        'Library',
        'Containers',
        'com.example.flowlogClient',
        'Data',
        'Documents',
        'flowlog.sqlite',
      ),
    ]);
  }
  return paths.map(File.new).where((file) => file.existsSync()).toList();
}

File _bestLegacyDatabase(List<File> legacyCandidates) {
  return legacyCandidates.firstWhere(
    (file) => _taskCountInDatabase(file) > 0,
    orElse: () => legacyCandidates.first,
  );
}

String? _resolveHomeDirectory({
  required String? homeDirectory,
  required Directory appSupportDirectory,
  required Directory documentsDirectory,
}) {
  if (homeDirectory != null && homeDirectory.trim().isNotEmpty) {
    return homeDirectory.trim();
  }
  for (final path in [documentsDirectory.path, appSupportDirectory.path]) {
    final marker = '${p.separator}Library${p.separator}';
    final index = path.indexOf(marker);
    if (index > 0) {
      return path.substring(0, index);
    }
  }
  return null;
}

Future<void> _copySqliteDatabase(File source, File target) async {
  await target.parent.create(recursive: true);
  await source.copy(target.path);
  for (final suffix in ['-wal', '-shm']) {
    final sidecar = File('${source.path}$suffix');
    if (sidecar.existsSync()) {
      await sidecar.copy('${target.path}$suffix');
    }
  }
}

Future<bool> _shouldReplaceEmptyTarget(
  File target,
  List<File> legacyCandidates,
) async {
  if (legacyCandidates.isEmpty) return false;
  final targetTasks = _taskCountInDatabase(target);
  if (targetTasks != 0) return false;
  for (final legacy in legacyCandidates) {
    if (_taskCountInDatabase(legacy) > 0) {
      return true;
    }
  }
  return false;
}

int _taskCountInDatabase(File file) {
  sqlite3.Database? db;
  try {
    db = sqlite3.sqlite3.open(file.path, mode: sqlite3.OpenMode.readOnly);
    final hasTasks = db
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tasks'",
        )
        .isNotEmpty;
    if (!hasTasks) return 0;
    return db.select('SELECT COUNT(*) AS count FROM tasks').first['count']
        as int;
  } catch (_) {
    return 0;
  } finally {
    db?.dispose();
  }
}
