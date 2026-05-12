import 'package:drift/drift.dart';

// ============================================================================
// 任务表
// ----------------------------------------------------------------------------
// M1_01 改动：
//   * serverId Int → Text（同步层会用 UUID 风格 ID）
//   * 新增 notes（Markdown），暂时与旧 content 共存，M2 重构 UI 后删除 content
//   * When 双轴：whenType + dueDate 同事务维护；evening 是 Today 视图分组冗余字段
//   * deadline / reminderAt 与 dueDate 解耦
//   * headingId：项目内分节
//   * sortOrder：手动拖拽排序
//   * inLogbook：完成后是否进入 Logbook（默认 true）
// ============================================================================
class Tasks extends Table {
  // 主键：客户端生成 UUID
  TextColumn get id => text()();

  // 服务端 ID（同步后回填）
  TextColumn get serverId => text().nullable()();

  // 标题
  TextColumn get title => text().withLength(min: 1, max: 500)();

  // 备注/描述（旧字段，M2 视图重写后退役）
  TextColumn get content => text().nullable()();

  // Markdown 备注（M1 新增，逐步替代 content）
  TextColumn get notes => text().withDefault(const Constant(''))();

  // 优先级 (0:None, 1:Low, 3:Medium, 5:High)
  IntColumn get priority => integer().withDefault(const Constant(0))();

  // ── When 双轴 ───────────────────────────────────────────────────────────
  // whenType: 0=none, 1=today, 2=thisEvening, 3=someday, 4=scheduled
  IntColumn get whenType => integer().withDefault(const Constant(0))();

  // 计划日期：whenType=4 时必填，whenType=1 时通常等于 today
  DateTimeColumn get dueDate => dateTime().nullable()();

  // 截止日期：与 dueDate 解耦，UI 渲染红色 "⚑" 徽标
  DateTimeColumn get deadline => dateTime().nullable()();

  // 提醒时刻：与 dueDate 解耦
  DateTimeColumn get reminderAt => dateTime().nullable()();

  // 旧字段：兼容期保留，等同 dueDate 的"段尾"
  DateTimeColumn get endDate => dateTime().nullable()();

  // 是否全天任务
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();

  // Today 视图下"This Evening"分组冗余字段，与 whenType=2 配合提速查询
  BoolColumn get evening => boolean().withDefault(const Constant(false))();

  // ── 重复 ────────────────────────────────────────────────────────────────
  // 重复规则 (RFC 5545 RRULE)
  TextColumn get repeatRule => text().nullable()();

  // 重复模式 (BY_DUE / BY_COMPLETE)
  TextColumn get repeatMode => text().nullable()();

  // 重复截止
  DateTimeColumn get repeatUntil => dateTime().nullable()();

  // ── 关系 ────────────────────────────────────────────────────────────────
  // 父任务 ID（子任务关联）
  TextColumn get parentId => text().nullable()();

  // 所属清单 ID
  TextColumn get projectId => text().nullable()();

  // 项目内分节 ID
  TextColumn get headingId => text().nullable()();

  // ── 状态 ────────────────────────────────────────────────────────────────
  // 状态 (0:Todo, 1:Done, 2:Deleted)
  IntColumn get status => integer().withDefault(const Constant(0))();

  // 完成时间
  DateTimeColumn get completedAt => dateTime().nullable()();

  // 完成后是否进入 Logbook（个别隐藏类任务可设 false）
  BoolColumn get inLogbook => boolean().withDefault(const Constant(true))();

  // ── 排序 ────────────────────────────────────────────────────────────────
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // ── 同步 ────────────────────────────────────────────────────────────────
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// 区域（Area）：项目分组容器
// ----------------------------------------------------------------------------
// Things 中位于 Project 之上，例如"工作 / 生活 / 学习"。Area 不直接承载任务，
// 仅用于 sidebar 折叠分组。
// ============================================================================
class Areas extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get name => text().withLength(min: 1, max: 128)();
  TextColumn get iconName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// 清单（Project）
// ----------------------------------------------------------------------------
// M1_01 改动：
//   * color Int → Text nullable，存 "#AARRGGBB" 字符串
//   * 新增 serverId / iconName / notes / areaId / whenType / deadline / status /
//     completedAt / sortOrder
//   * status: 0=Active, 1=Completed, 2=Cancelled, 3=Deleted
// ============================================================================
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get name => text().withLength(min: 1, max: 128)();

  // 颜色：存 "#AARRGGBB" 字符串；nullable 表示沿用主题默认色
  TextColumn get color => text().nullable()();

  // 项目图标 key（SF Symbol 名 / 自定义图标 key）
  TextColumn get iconName => text().nullable()();

  // 项目说明
  TextColumn get notes => text().withDefault(const Constant(''))();

  // 归属 Area
  TextColumn get areaId => text().nullable()();

  // 项目本身的 When（项目级 schedule）
  IntColumn get whenType => integer().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime().nullable()();

  // 状态 (0:Active, 1:Completed, 2:Cancelled, 3:Deleted)
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  // 排序
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// 项目内分节（Heading）
// ----------------------------------------------------------------------------
// 不是任务，用于在长项目中分隔大量任务。可归档（archivedAt 非空）。
// ============================================================================
class Headings extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();

  TextColumn get projectId => text()();
  TextColumn get title => text().withLength(min: 1, max: 256)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// 任务内勾选清单（Checklist）
// ----------------------------------------------------------------------------
// 不是 Subtask：没有自己的 due/priority/tags，只有标题 + 勾选状态。
// 同步粒度跟随父任务。
// ============================================================================
class Checklists extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// 标签 / 关联表
// ============================================================================
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class AiSuggestions extends Table {
  TextColumn get id => text()();
  TextColumn get surface => text()();
  TextColumn get toolName => text()();
  TextColumn get argsJson => text()();
  TextColumn get previewText => text()();
  TextColumn get previewJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get rejectionReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get conversationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AiActionLog extends Table {
  TextColumn get id => text()();
  TextColumn get toolName => text()();
  TextColumn get argsJson => text()();
  TextColumn get resultJson => text()();
  TextColumn get trustLevel => text()();
  TextColumn get origin => text()();
  TextColumn get conversationId => text().nullable()();
  BoolColumn get undone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get undoneAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AiConversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get contextJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class AiMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(AiConversations, #id)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get toolCallsJson => text().nullable()();
  TextColumn get toolResultsJson => text().nullable()();
  BoolColumn get isError => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class AiCoachInsights extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  DateTimeColumn get periodStart => dateTime()();
  DateTimeColumn get periodEnd => dateTime()();
  TextColumn get summaryMd => text()();
  TextColumn get metricsJson => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class AiSuggestionRules extends Table {
  TextColumn get id => text()();
  TextColumn get patternType => text()();
  TextColumn get patternValue => text()();
  TextColumn get scope => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get etag => text().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
