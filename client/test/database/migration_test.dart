// ignore_for_file: avoid_print

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowlog_client/database/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// v8 schema 的最小重建脚本。
///
/// 字段顺序与 git history 中的 `tables.dart` v8 版本对齐；列名按 Drift
/// 默认的 snake_case 转换。仅创建迁移会读到的列即可。
const _v8Schema = '''
CREATE TABLE tasks (
  id TEXT NOT NULL PRIMARY KEY,
  server_id INTEGER,
  title TEXT NOT NULL,
  content TEXT,
  priority INTEGER NOT NULL DEFAULT 0,
  due_date INTEGER,
  end_date INTEGER,
  is_all_day INTEGER NOT NULL DEFAULT 0,
  repeat_rule TEXT,
  repeat_mode TEXT,
  repeat_until INTEGER,
  parent_id TEXT,
  project_id TEXT,
  status INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE projects (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  color INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE tags (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  color INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE task_tags (
  task_id TEXT NOT NULL REFERENCES tasks(id),
  tag_id TEXT NOT NULL REFERENCES tags(id),
  PRIMARY KEY (task_id, tag_id)
);
''';

void main() {
  group('v8 → v10 migration', () {
    late Database raw;
    late AppDatabase db;

    setUp(() async {
      raw = sqlite3.openInMemory();

      // 1. 建 v8 schema
      raw.execute(_v8Schema);

      // 2. 设置 user_version=8 让 Drift 走 onUpgrade 路径
      raw.execute('PRAGMA user_version = 8;');

      // 3. 注入测试数据
      // Drift 2.30+ 把 DateTime 存为 unix seconds（millisecondsSinceEpoch ~/ 1000）。
      // 这里 raw INSERT 必须用秒级时间戳，否则 v9 migration 的 whenType 回填
      // 按 'unixepoch' 解析时拿到的就不是真正的"今天"。
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final today = DateTime.now();
      final todayStartSec =
          DateTime(today.year, today.month, today.day).millisecondsSinceEpoch ~/
              1000;
      final tomorrowSec = DateTime(today.year, today.month, today.day + 1)
              .millisecondsSinceEpoch ~/
          1000;

      // 项目：旧 int 颜色（4281559091 = 0xFF336833，不一定是设计稿值，但
      // 我们关心的是它能正确转换为 8 位 hex 字符串）
      raw.execute(
        "INSERT INTO projects (id, name, color, created_at, updated_at) "
        "VALUES ('p1', 'Project One', 4281559091, $nowSec, $nowSec);",
      );

      // 任务 t1：有 content + 整数 server_id + dueDate=今天 → whenType 应为 1
      raw.execute(
        "INSERT INTO tasks "
        "(id, server_id, title, content, due_date, project_id, "
        " status, is_dirty, created_at, updated_at) "
        "VALUES ('t1', 999, 'Task 1', 'note one', $todayStartSec, 'p1', "
        "        0, 1, $nowSec, $nowSec);",
      );

      // 任务 t2：无 content / 无 server_id / dueDate=明天 → whenType 应为 4
      raw.execute(
        "INSERT INTO tasks "
        "(id, title, due_date, status, is_dirty, created_at, updated_at) "
        "VALUES ('t2', 'Task 2', $tomorrowSec, 0, 1, ${nowSec - 1}, ${nowSec - 1});",
      );

      // 任务 t3：无 dueDate → whenType 应为 0
      raw.execute(
        "INSERT INTO tasks "
        "(id, title, status, is_dirty, created_at, updated_at) "
        "VALUES ('t3', 'Task 3', 0, 1, ${nowSec - 2}, ${nowSec - 2});",
      );

      // 4. 包成 Drift 数据库（构造时不连，第一次查询触发迁移）
      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion bumps to 10 after first query', () async {
      // 任意查询触发 migration
      await db.customSelect('SELECT 1').get();
      final result = await db.customSelect('PRAGMA user_version').getSingle();
      expect(result.read<int>('user_version'), 10);
    });

    test('Tasks: notes 由 content 回填，server_id 从 int 转 string', () async {
      final t1 = await (db.select(db.tasks)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(t1.notes, 'note one');
      expect(t1.serverId, '999');

      final t2 = await (db.select(db.tasks)..where((t) => t.id.equals('t2')))
          .getSingle();
      expect(t2.notes, '');
      expect(t2.serverId, isNull);
    });

    test('Tasks: whenType 按 dueDate 推断', () async {
      final t1 = await (db.select(db.tasks)..where((t) => t.id.equals('t1')))
          .getSingle();
      // dueDate 是今天 → today (1)
      expect(t1.whenType, WhenType.today.value);

      final t2 = await (db.select(db.tasks)..where((t) => t.id.equals('t2')))
          .getSingle();
      // dueDate 是明天 → scheduled (4)
      expect(t2.whenType, WhenType.scheduled.value);

      final t3 = await (db.select(db.tasks)..where((t) => t.id.equals('t3')))
          .getSingle();
      // 无 dueDate → none (0)
      expect(t3.whenType, WhenType.none.value);
    });

    test('Tasks: sortOrder 按 createdAt 顺序在每个 project 内重置', () async {
      final t1 = await (db.select(db.tasks)..where((t) => t.id.equals('t1')))
          .getSingle();
      final t2 = await (db.select(db.tasks)..where((t) => t.id.equals('t2')))
          .getSingle();
      final t3 = await (db.select(db.tasks)..where((t) => t.id.equals('t3')))
          .getSingle();
      // t1 在 'p1' 项目里，独占一组，sortOrder 应为 0
      expect(t1.sortOrder, 0);
      // t2 / t3 都没有 projectId（NULL 视作同一组），按 createdAt 升序
      // t3.createdAt < t2.createdAt → t3 排前
      expect(t3.sortOrder, 0);
      expect(t2.sortOrder, 1);
    });

    test('Tasks: 默认值生效（evening=false, sortOrder>=0, inLogbook=true）', () async {
      final t1 = await (db.select(db.tasks)..where((t) => t.id.equals('t1')))
          .getSingle();
      expect(t1.evening, isFalse);
      expect(t1.inLogbook, isTrue);
      expect(t1.sortOrder, isNonNegative);
      expect(t1.deadline, isNull);
      expect(t1.reminderAt, isNull);
      expect(t1.headingId, isNull);
    });

    test('Projects: color 从 int 转换为 #AARRGGBB hex 字符串', () async {
      final p = await (db.select(db.projects)..where((p) => p.id.equals('p1')))
          .getSingle();
      expect(p.color, isNotNull);
      expect(p.color, matches(RegExp(r'^#[0-9A-F]{8}$')));
      // 对 4281559091（= 0xFF336833），printf('#%08X', ...) 输出 #FF336833
      expect(p.color, '#FF336833');
    });

    test('Projects: 新增字段默认值正确', () async {
      final p = await (db.select(db.projects)..where((p) => p.id.equals('p1')))
          .getSingle();
      expect(p.serverId, isNull);
      expect(p.iconName, isNull);
      expect(p.notes, '');
      expect(p.areaId, isNull);
      expect(p.whenType, 0);
      expect(p.deadline, isNull);
      expect(p.status, 0);
      expect(p.completedAt, isNull);
      expect(p.sortOrder, 0);
    });

    test('新表存在且为空：Areas / Headings / Checklists', () async {
      expect(await db.select(db.areas).get(), isEmpty);
      expect(await db.select(db.headings).get(), isEmpty);
      expect(await db.select(db.checklists).get(), isEmpty);
    });

    test('AI 本地表存在且为空', () async {
      await db.customSelect('SELECT 1').get();

      expect(await db.select(db.aiSuggestions).get(), isEmpty);
      expect(await db.select(db.aiActionLog).get(), isEmpty);
      expect(await db.select(db.aiConversations).get(), isEmpty);
      expect(await db.select(db.aiMessages).get(), isEmpty);
      expect(await db.select(db.aiCoachInsights).get(), isEmpty);
      expect(await db.select(db.aiSuggestionRules).get(), isEmpty);
    });

    test('AI suggestions 索引存在', () async {
      await db.customSelect('SELECT 1').get();

      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'ai_suggestions'",
          )
          .get();
      final names = indexes.map((row) => row.read<String>('name')).toSet();
      expect(names, contains('idx_ai_suggestions_status_created_at'));
      expect(names, contains('idx_ai_suggestions_surface_status'));
    });

    test('迁移后能继续插入并查询', () async {
      // 触发迁移
      await db.customSelect('SELECT 1').get();

      final areaId = await db.insertArea('Work');
      final areas = await db.select(db.areas).get();
      expect(areas.length, 1);
      expect(areas.first.id, areaId);
      expect(areas.first.name, 'Work');

      final headingId = await db.insertHeading('p1', 'Q1 Goals');
      final headings = await db.watchHeadings('p1').first;
      expect(headings.length, 1);
      expect(headings.first.id, headingId);

      final checklistId = await db.insertChecklistItem('t1', 'sub item');
      final items = await db.watchChecklist('t1').first;
      expect(items.length, 1);
      expect(items.first.id, checklistId);
      expect(items.first.isChecked, isFalse);

      await db.toggleChecklistItem(checklistId, true);
      final updated = await db.watchChecklist('t1').first;
      expect(updated.first.isChecked, isTrue);
    });

    test('迁移后 setTaskWhen 同事务维护 dueDate / whenType', () async {
      await db.customSelect('SELECT 1').get();

      // t3 原本是 none，改 thisEvening 应同时设置 dueDate=今天 + evening=true
      await db.setTaskWhen('t3', WhenType.thisEvening);
      final t3 = await (db.select(db.tasks)..where((t) => t.id.equals('t3')))
          .getSingle();
      expect(t3.whenType, WhenType.thisEvening.value);
      expect(t3.evening, isTrue);
      expect(t3.dueDate, isNotNull);

      // 改 someday 应清空 dueDate / evening
      await db.setTaskWhen('t3', WhenType.someday);
      final t3b = await (db.select(db.tasks)..where((t) => t.id.equals('t3')))
          .getSingle();
      expect(t3b.whenType, WhenType.someday.value);
      expect(t3b.dueDate, isNull);
      expect(t3b.evening, isFalse);

      // scheduled 不带 date 应回退到 none
      await db.setTaskWhen('t3', WhenType.scheduled);
      final t3c = await (db.select(db.tasks)..where((t) => t.id.equals('t3')))
          .getSingle();
      expect(t3c.whenType, WhenType.none.value);
      expect(t3c.dueDate, isNull);
    });

    test('moveTaskToProject：sortOrder 在目标分组内末尾追加', () async {
      await db.customSelect('SELECT 1').get();

      // 初始状态：t1 在 p1 (sortOrder=0)；t2/t3 在 inbox (sortOrder=0,1)
      // 把 t2 移到 p1 → sortOrder 应为 1 (max+1)
      await db.moveTaskToProject('t2', 'p1');
      final t2 = await (db.select(db.tasks)..where((t) => t.id.equals('t2')))
          .getSingle();
      expect(t2.projectId, 'p1');
      expect(t2.sortOrder, 1);

      // 再移 t3 → sortOrder=2
      await db.moveTaskToProject('t3', 'p1');
      final t3 = await (db.select(db.tasks)..where((t) => t.id.equals('t3')))
          .getSingle();
      expect(t3.sortOrder, 2);
    });

    test('reorderTasks：按入参顺序重写 sortOrder', () async {
      await db.customSelect('SELECT 1').get();

      await db.reorderTasks(['t3', 't1', 't2']);
      final ts = await (db.select(db.tasks)
            ..where((t) => t.id.isIn(['t1', 't2', 't3'])))
          .get();
      final byId = {for (final t in ts) t.id: t.sortOrder};
      expect(byId['t3'], 0);
      expect(byId['t1'], 1);
      expect(byId['t2'], 2);
    });

    test('insertTask 默认进入 Inbox 语义（whenType=0, projectId 由调用者决定）', () async {
      await db.customSelect('SELECT 1').get();

      const id = 'newtask';
      final now = DateTime.now();
      await db.insertTask(
        TasksCompanion.insert(
          id: id,
          title: 'Brand new',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      final row = await (db.select(db.tasks)..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.whenType, 0);
      expect(row.evening, isFalse);
      expect(row.inLogbook, isTrue);
    });
  });

  // ==========================================================================
  // 历史升级路径：v1 → v10 一步到位
  // --------------------------------------------------------------------------
  // 这条路径上要踩两个曾经的雷：
  //   * `_normalizeLegacyDateTimes` 在 from<5 阶段被调用时，end_date /
  //     repeat_until / parent_id 这些列还没加；早先的实现写死列名会让 v1 用户
  //     的升级直接 hard-fail（fix: P1.1 的 _columnsOf 探测）。
  //   * `_migrateToThingsAlignment` 在 from<2 路径上看到的 projects 表是 Drift
  //     按 v9 Dart 定义新建的，已经是 hex color；不能再当 v8 跑 TableMigration
  //     （fix: P1.2 的 tasksAlreadyV9 / projectsAlreadyV9 探测）。
  // ==========================================================================
  group('v1 → v10 migration', () {
    late Database raw;
    late AppDatabase db;

    /// v1 schema：只有 tasks 表，且没有 end_date / parent_id / repeat_*。
    /// server_id 早在 v1 就有（IntColumn）；projects / tags / task_tags
    /// 完全不存在，由后续 from<2 路径用 m.createTable 创建出 v9 形态。
    const v1Tasks = '''
CREATE TABLE tasks (
  id TEXT NOT NULL PRIMARY KEY,
  server_id INTEGER,
  title TEXT NOT NULL,
  content TEXT,
  priority INTEGER NOT NULL DEFAULT 0,
  due_date INTEGER,
  is_all_day INTEGER NOT NULL DEFAULT 0,
  project_id TEXT,
  status INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''';

    setUp(() async {
      raw = sqlite3.openInMemory();
      raw.execute(v1Tasks);
      raw.execute('PRAGMA user_version = 1;');

      // 一条很老的任务，dueDate=今天，预期升级后 whenType=today
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final today = DateTime.now();
      final todayStartSec =
          DateTime(today.year, today.month, today.day).millisecondsSinceEpoch ~/
              1000;
      raw.execute(
        "INSERT INTO tasks "
        "(id, title, content, due_date, status, is_dirty, created_at, updated_at) "
        "VALUES ('legacy', 'Legacy', 'old note', $todayStartSec, 0, 1, $nowSec, $nowSec);",
      );

      db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() async {
      await db.close();
    });

    test('一路升到 v10，schemaVersion 推进、不抛异常', () async {
      await db.customSelect('SELECT 1').get();
      final result = await db.customSelect('PRAGMA user_version').getSingle();
      expect(result.read<int>('user_version'), 10);
    });

    test('既有 v1 任务的 notes / whenType / 默认值都正确回填', () async {
      final t = await (db.select(db.tasks)..where((x) => x.id.equals('legacy')))
          .getSingle();
      expect(t.notes, 'old note');
      expect(t.whenType, WhenType.today.value);
      expect(t.evening, isFalse);
      expect(t.inLogbook, isTrue);
      expect(t.serverId, isNull); // v1 没 server_id 列，迁移后默认 null
    });

    test('Projects 表由 from<2 用 v9 形态新建，color 已是 hex（未被误解析为 0）', () async {
      // _seedDefaultProjects 在 onUpgrade 的 from<2 路径里跑，写入的是
      // `'#FF4287F5'` / `'#FF36AB10'` 风格的 hex；如果 _migrateToThingsAlignment
      // 没探测就直接走 TableMigration + printf，会被改成 '#00000000'。
      final all = await db.select(db.projects).get();
      final ids = all.map((p) => p.id).toSet();
      expect(ids, containsAll(['work', 'personal']));
      for (final p in all) {
        expect(p.color, matches(RegExp(r'^#[0-9A-F]{8}$')));
        expect(p.color, isNot('#00000000'));
      }
    });

    test('Areas / Headings / Checklists 三张新表存在且为空', () async {
      expect(await db.select(db.areas).get(), isEmpty);
      expect(await db.select(db.headings).get(), isEmpty);
      expect(await db.select(db.checklists).get(), isEmpty);
    });

    test('AI 表也会在历史升级路径创建', () async {
      await db.customSelect('SELECT 1').get();

      expect(await db.select(db.aiSuggestions).get(), isEmpty);
      expect(await db.select(db.aiActionLog).get(), isEmpty);
      expect(await db.select(db.aiConversations).get(), isEmpty);
      expect(await db.select(db.aiMessages).get(), isEmpty);
      expect(await db.select(db.aiCoachInsights).get(), isEmpty);
      expect(await db.select(db.aiSuggestionRules).get(), isEmpty);
    });
  });
}
