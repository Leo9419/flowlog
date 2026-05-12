# M1-01 数据模型重构（对齐 Things）

> 一次性升级 Drift schema：新增 Area / Heading / Checklist 三张表，扩展 Tasks 与 Projects 字段，加 schema migration 与新查询。

## 1. 目标

- 引入 Things 的 **Area > Project > Heading > Task > Checklist** 五级结构。
- Tasks 表区分 **When（计划做的日期/语义）** 和 **Deadline（必须前完成）**，并独立 reminder。
- 一次到位，避免 M2 视图层重构时再改 schema。
- 旧数据零丢失，`notes` / `whenType` 自动从 `content` / `dueDate` 推断填充。

## 2. 现状

来自 `client/lib/database/tables.dart`：

```
Tasks(id, serverId, title, content, priority, dueDate, endDate, isAllDay,
      repeatRule, repeatMode, repeatUntil, parentId, projectId,
      status, completedAt, isDirty, createdAt, updatedAt)
Projects(id, name, color, createdAt, updatedAt)
Tags(id, name, color, sortOrder)
TaskTags(taskId, tagId)
```

### 缺口

| Things 概念 | flowlog 当前 | 缺口 |
|---|---|---|
| Area（项目分组） | 无 | 需新增 Areas 表 + Project.areaId |
| Heading（项目内分节） | 无 | 需新增 Headings 表 + Task.headingId |
| Checklist（任务内勾选） | 用 parentId 实现的子任务 | Checklist ≠ Subtask，需独立 Checklists 表 |
| When = Today / Evening / Anytime / Someday / Scheduled | 仅 dueDate | 需 whenType 字段 |
| Deadline（必须前完成） | 与 dueDate 混用 | 需独立 deadline 字段 |
| Reminder（独立提醒时刻） | 与 dueDate 绑定 | 需独立 reminderAt |
| Markdown notes | content（普通文本） | 升为 Markdown，字段重命名 |
| 拖拽排序 | 无 | 需 sortOrder（Tasks / Projects / Areas / Headings 都加）|

## 3. 目标 Schema

### 3.1 Tasks 表（修改）

```dart
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();   // ← 新，Markdown
  TextColumn get content => text().withDefault(const Constant(''))(); // ← 保留一版后删除（M2）

  IntColumn get priority => integer().withDefault(const Constant(0))();

  // —— When 双轴 ——
  IntColumn get whenType => integer().withDefault(const Constant(0))();
  // 0=none, 1=today, 2=thisEvening, 3=someday, 4=scheduled
  DateTimeColumn get dueDate => dateTime().nullable()();      // 计划日期（保留语义）
  DateTimeColumn get deadline => dateTime().nullable()();     // ← 新，截止日
  DateTimeColumn get reminderAt => dateTime().nullable()();   // ← 新，独立提醒
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(true))();
  BoolColumn get evening => boolean().withDefault(const Constant(false))(); // ← 新，Today 下"This Evening"分组冗余字段（与 whenType=2 配合，便于查询）

  // —— 重复 ——
  TextColumn get repeatRule => text().nullable()();
  TextColumn get repeatMode => text().nullable()();
  DateTimeColumn get repeatUntil => dateTime().nullable()();

  // —— 关系 ——
  TextColumn get parentId => text().nullable()();              // 子任务（保留）
  TextColumn get projectId => text().nullable()();
  TextColumn get headingId => text().nullable()();             // ← 新，项目内分节

  // —— 状态 ——
  IntColumn get status => integer().withDefault(const Constant(0))();
  // 0=Todo, 1=Done, 2=Deleted
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get inLogbook => boolean().withDefault(const Constant(true))(); // ← 新，完成是否进 Logbook

  // —— 排序 ——
  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // ← 新

  // —— 同步 ——
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override Set<Column> get primaryKey => {id};
}
```

字段语义说明：

| 字段 | 写入时机 |
|---|---|
| `whenType=1 today` | 用户在 When picker 选 "Today"；UI 上出现在 Today 视图 |
| `whenType=2 thisEvening` | 选 "This Evening"；Today 视图下 Evening 分组 |
| `whenType=3 someday` | 选 "Someday"；Anytime 视图过滤掉，Someday 视图展示 |
| `whenType=4 scheduled` | 选具体日期 → 同时写 `dueDate` |
| `whenType=0 none` | 默认，Anytime 视图展示 |
| `deadline` | 与 whenType 独立。一个任务可以是 "Anytime + 周五 deadline" |
| `reminderAt` | 与 dueDate 独立。可以是 "下周一做，但今晚 21:00 提醒" |

### 3.2 Projects 表（修改）

```dart
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get name => text()();
  TextColumn get color => text().nullable()();                  // 已有
  TextColumn get iconName => text().nullable()();               // ← 新，SF Symbol / 自定义图标 key
  TextColumn get notes => text().withDefault(const Constant(''))(); // ← 新

  TextColumn get areaId => text().nullable()();                 // ← 新，归属 Area
  IntColumn get whenType => integer().withDefault(const Constant(0))(); // ← 新，项目本身的 When
  DateTimeColumn get deadline => dateTime().nullable()();       // ← 新

  IntColumn get status => integer().withDefault(const Constant(0))(); // ← 新：0=Active, 1=Completed, 2=Cancelled, 3=Deleted
  DateTimeColumn get completedAt => dateTime().nullable()();    // ← 新

  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // ← 新

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override Set<Column> get primaryKey => {id};
}
```

### 3.3 新增 Areas 表

```dart
class Areas extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get name => text()();
  TextColumn get iconName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override Set<Column> get primaryKey => {id};
}
```

### 3.4 新增 Headings 表

```dart
class Headings extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get projectId => text()();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override Set<Column> get primaryKey => {id};
}
```

### 3.5 新增 Checklists 表

```dart
class Checklists extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get title => text()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override Set<Column> get primaryKey => {id};
}
```

> Checklist ≠ Subtask 的取舍：Checklist 是任务"内部 UI"，没有独立的 due/priority/tags；Subtask 仍然走 `Tasks.parentId`，是完整任务对象。两者并存。

### 3.6 Tags / TaskTags 表
保持不变。

## 4. Drift Schema Migration

### 4.1 版本号

`client/lib/database/database.dart`：
```dart
@override
int get schemaVersion => /* 当前值 */ + 1;
```

### 4.2 迁移脚本

新建 `client/lib/database/migrations/v_things_alignment.dart`：

```dart
Future<void> migrateToThingsAlignment(Migrator m, AppDatabase db) async {
  // 1. 新表
  await m.createTable(db.areas);
  await m.createTable(db.headings);
  await m.createTable(db.checklists);

  // 2. Tasks 加列
  await m.addColumn(db.tasks, db.tasks.notes);
  await m.addColumn(db.tasks, db.tasks.whenType);
  await m.addColumn(db.tasks, db.tasks.deadline);
  await m.addColumn(db.tasks, db.tasks.reminderAt);
  await m.addColumn(db.tasks, db.tasks.evening);
  await m.addColumn(db.tasks, db.tasks.headingId);
  await m.addColumn(db.tasks, db.tasks.sortOrder);
  await m.addColumn(db.tasks, db.tasks.inLogbook);

  // 3. Projects 加列
  await m.addColumn(db.projects, db.projects.iconName);
  await m.addColumn(db.projects, db.projects.notes);
  await m.addColumn(db.projects, db.projects.areaId);
  await m.addColumn(db.projects, db.projects.whenType);
  await m.addColumn(db.projects, db.projects.deadline);
  await m.addColumn(db.projects, db.projects.status);
  await m.addColumn(db.projects, db.projects.completedAt);
  await m.addColumn(db.projects, db.projects.sortOrder);

  // 4. 数据回填：content → notes
  await db.customStatement(
    "UPDATE tasks SET notes = COALESCE(content, '') WHERE notes = ''",
  );

  // 5. 数据回填：dueDate → whenType
  // 规则：
  //   dueDate 为 NULL 且 projectId 为 NULL → whenType=0 (none)，进 Inbox/Anytime
  //   dueDate 为今天 → whenType=1 (today)
  //   dueDate 为未来某天 → whenType=4 (scheduled)
  //   dueDate 为过去某天 → 保留 whenType=4，UI 显示为逾期
  //   其他无规则匹配 → whenType=0
  await db.customStatement('''
    UPDATE tasks SET whenType = CASE
      WHEN dueDate IS NULL THEN 0
      WHEN date(dueDate / 1000, 'unixepoch', 'localtime') = date('now', 'localtime') THEN 1
      ELSE 4
    END
  ''');

  // 6. sortOrder 初始化：按 createdAt 排序
  await db.customStatement('''
    UPDATE tasks SET sortOrder = (
      SELECT COUNT(*) FROM tasks t2
      WHERE t2.projectId IS tasks.projectId AND t2.createdAt < tasks.createdAt
    )
  ''');
}
```

### 4.3 接入 `MigrationStrategy`

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < /* 新版本号 */) {
      await migrateToThingsAlignment(m, this);
    }
  },
);
```

### 4.4 重新生成 codegen

```bash
cd client
dart run build_runner build --delete-conflicting-outputs
```

确认 `client/lib/database/database.g.dart` 已包含新表与新列。

## 5. 新增查询 API

`client/lib/database/database.dart` 增加：

| 方法 | 返回 | SQL 摘要 |
|---|---|---|
| `watchTodayWithEvening()` | `({List<Task> morning, List<Task> evening, List<Task> overdue})` | 三段式：whenType=1 + evening=false / whenType=2 / 逾期 |
| `watchAnytimeTasks()` | `Stream<List<Task>>` | `whenType IN (0, 4) AND status=0 AND projectId IS NULL` 与项目内任务合并 |
| `watchSomedayTasks()` | `Stream<List<Task>>` | `whenType=3 AND status=0` |
| `watchLogbook({int days = 90})` | `Stream<List<Task>>` | `status=1 AND inLogbook=true` 按 `completedAt DESC` |
| `watchAreas()` | `Stream<List<Area>>` | 按 sortOrder |
| `watchProjectsByArea(String? areaId)` | `Stream<List<Project>>` | `areaId IS ?` 过滤 |
| `watchHeadings(String projectId)` | `Stream<List<Heading>>` | `projectId=?` 按 sortOrder |
| `watchChecklist(String taskId)` | `Stream<List<ChecklistItem>>` | 按 sortOrder |
| `watchProjectProgress(String projectId)` | `Stream<({int done, int total})>` | 用于 sidebar 进度环 |
| `watchTasksByHeading(String headingId)` | `Stream<List<Task>>` | 项目页分节渲染 |

### 5.1 写入 API

| 方法 | 说明 |
|---|---|
| `setTaskWhen(taskId, WhenType, {DateTime? date})` | 同时维护 `whenType` 和 `dueDate` |
| `setTaskDeadline(taskId, DateTime?)` | 仅 deadline |
| `setTaskReminder(taskId, DateTime?)` | 仅 reminder，并触发 `notification_service` 调度 |
| `moveTaskToProject(taskId, projectId, {String? headingId})` | 带 sortOrder 重排 |
| `reorderTasks(List<String> idsInOrder)` | 拖拽排序 |
| `insertChecklistItem` / `toggleChecklistItem` / `reorderChecklist` | Checklist CRUD |
| `insertHeading` / `archiveHeading` / `reorderHeadings` | Heading CRUD |
| `insertArea` / `reorderAreas` | Area CRUD |

## 6. 文件清单

### 新增
```
client/lib/database/migrations/v_things_alignment.dart
client/lib/data/area_repository.dart
client/lib/data/heading_repository.dart
client/lib/data/checklist_repository.dart
client/test/database/migration_test.dart
client/test/database/queries_test.dart
```

### 修改
```
client/lib/database/tables.dart           — 加表 / 加字段
client/lib/database/database.dart          — schemaVersion+1 / migration / 新查询 / 新写入
client/lib/database/database.g.dart        — codegen 自动生成
```

## 7. 实施步骤（小步 commit）

1. `feat(db): add Areas/Headings/Checklists table definitions` — 仅改 `tables.dart`，跑 codegen，确认编译通过。
2. `feat(db): extend Tasks/Projects with Things-aligned columns` — 加字段 + codegen。
3. `feat(db): add migration v_things_alignment` — 写 migration + 在 `database.dart` 接入。
4. `test(db): cover migration with seeded v1 data` — 单元测试：手动构造旧 schema 数据 → upgrade → 断言 notes/whenType 正确。
5. `feat(db): add Anytime/Someday/Logbook queries` — 加查询。
6. `feat(db): add reorder & checklist & heading & area write APIs` — 加写入。
7. `test(db): cover new queries & write APIs` — 测试。

## 8. 风险与注意事项

| 风险 | 应对 |
|---|---|
| 旧用户升级失败导致数据丢失 | 迁移脚本前先 `customStatement('PRAGMA foreign_keys=OFF')`；迁移完整跑通后再开。 |
| `notes` 与 `content` 双写期 | M1 期间 UI 写入仍走 `content`，读取优先 `notes` 回退 `content`；M2 全量迁出后下个 schema 删 `content`。 |
| `whenType` 与 `dueDate` 一致性 | 写入 API 强制原子更新（同事务），禁止 UI 直接 `update(tasks)..write(...)`。 |
| 子任务 vs Checklist 概念混淆 | 文档与代码注释明确：Subtask 是 `Tasks(parentId=...)`，Checklist 是 `Checklists(taskId=...)`。 |
| sortOrder 冲突 | 重排时统一在 repository 内重算（步长 1），而不是在 UI 算。 |

## 9. 验收标准

1. ✅ `dart run build_runner build` 无错误，`database.g.dart` 包含新表与新列。
2. ✅ `client/test/database/migration_test.dart` 通过：构造旧版数据 → 升级 → `notes` / `whenType` 正确。
3. ✅ `client/test/database/queries_test.dart` 全部新查询有覆盖，至少各 1 条 happy-path。
4. ✅ 在已有 macOS 安装上 `flutter run`，原任务列表完整可见，没有崩溃日志。
5. ✅ 项目页（旧 UI）能正常列出任务（`headingId IS NULL` 时回退到现有 flat 列表）。
