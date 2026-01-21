import 'package:drift/drift.dart';

// 任务表定义
class Tasks extends Table {
  // 主键：客户端生成 UUID
  TextColumn get id => text()();
  
  // 服务端 ID（同步后回填）
  IntColumn get serverId => integer().nullable()();
  
  // 标题
  TextColumn get title => text().withLength(min: 1, max: 500)();
  
  // 备注/描述
  TextColumn get content => text().nullable()();
  
  // 优先级 (0:None, 1:Low, 3:Medium, 5:High)
  IntColumn get priority => integer().withDefault(const Constant(0))();
  
  // 截止日期 (DateTime -> ISO8601 String or Integer)
  // Drift 自动处理 DateTime
  DateTimeColumn get dueDate => dateTime().nullable()();
  
  // 是否全天任务
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  
  // 所属清单 ID (暂时默认 inbox)
  TextColumn get projectId => text().nullable()();
  
  // 状态 (0:Todo, 1:Done, 2:Deleted)
  IntColumn get status => integer().withDefault(const Constant(0))();
  
  // 完成时间
  DateTimeColumn get completedAt => dateTime().nullable()();
  
  // 同步标记
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  
  // 创建/更新时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
