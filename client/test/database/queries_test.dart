import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowlog_client/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late DateTime startOfToday;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.now();
    startOfToday = DateTime(now.year, now.month, now.day);
  });

  tearDown(() async {
    await db.close();
  });

  /// 插入一条最小可用的 Task。createdAt / updatedAt 默认 [now]。
  Future<void> insertTask({
    required String id,
    String title = 'Task',
    int whenType = 0,
    DateTime? dueDate,
    DateTime? deadline,
    DateTime? reminderAt,
    bool evening = false,
    int status = 0,
    DateTime? completedAt,
    String? projectId,
    String? headingId,
    String? parentId,
    int sortOrder = 0,
    bool inLogbook = true,
    DateTime? createdAt,
  }) async {
    final created = createdAt ?? now;
    await db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: id,
            title: title,
            whenType: Value(whenType),
            dueDate: Value(dueDate),
            deadline: Value(deadline),
            reminderAt: Value(reminderAt),
            evening: Value(evening),
            status: Value(status),
            completedAt: Value(completedAt),
            projectId: Value(projectId),
            headingId: Value(headingId),
            parentId: Value(parentId),
            sortOrder: Value(sortOrder),
            inLogbook: Value(inLogbook),
            createdAt: Value(created),
            updatedAt: Value(created),
          ),
        );
  }

  group('watchTodayWithEvening', () {
    test('partitions into morning / evening / overdue and excludes irrelevant',
        () async {
      // morning: whenType=today
      await insertTask(id: 'a', title: 'A', whenType: WhenType.today.value);
      // evening: whenType=thisEvening
      await insertTask(
        id: 'b',
        title: 'B',
        whenType: WhenType.thisEvening.value,
        evening: true,
      );
      // overdue: dueDate=yesterday, status=Todo
      await insertTask(
        id: 'c',
        title: 'C',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.subtract(const Duration(days: 1)),
      );
      // morning: whenType=scheduled with dueDate=today
      await insertTask(
        id: 'd',
        title: 'D',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday,
      );
      // excluded: whenType=someday
      await insertTask(id: 'e', title: 'E', whenType: WhenType.someday.value);
      // excluded: whenType=scheduled in future
      await insertTask(
        id: 'f',
        title: 'F',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.add(const Duration(days: 7)),
      );

      final sections = await db.watchTodayWithEvening().first;
      final morningIds = sections.morning.map((t) => t.id).toSet();
      final eveningIds = sections.evening.map((t) => t.id).toSet();
      final overdueIds = sections.overdue.map((t) => t.id).toSet();

      expect(morningIds, containsAll(['a', 'd']));
      expect(morningIds, isNot(contains('b')));
      expect(eveningIds, contains('b'));
      expect(overdueIds, contains('c'));
      expect(morningIds, isNot(contains('e')));
      expect(eveningIds, isNot(contains('f')));
    });

    test('excludes done & deleted tasks', () async {
      await insertTask(
        id: 'done',
        title: 'D',
        whenType: WhenType.today.value,
        status: 1,
        completedAt: now,
      );
      await insertTask(
        id: 'del',
        title: 'X',
        whenType: WhenType.today.value,
        status: 2,
      );
      final sections = await db.watchTodayWithEvening().first;
      expect(sections.morning, isEmpty);
      expect(sections.evening, isEmpty);
      expect(sections.overdue, isEmpty);
    });
  });

  group('watchAnytimeTasks', () {
    test('returns whenType none + scheduled; excludes today/someday/done',
        () async {
      await insertTask(id: 'a', whenType: WhenType.none.value);
      await insertTask(
        id: 'b',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.add(const Duration(days: 3)),
      );
      await insertTask(id: 'c', whenType: WhenType.today.value);
      await insertTask(id: 'd', whenType: WhenType.someday.value);
      await insertTask(id: 'e', whenType: WhenType.none.value, status: 1);

      final tasks = await db.watchAnytimeTasks().first;
      final ids = tasks.map((t) => t.id).toSet();
      expect(ids, equals({'a', 'b'}));
    });
  });

  group('watchSomedayTasks', () {
    test('returns only whenType=someday', () async {
      await insertTask(id: 'a', whenType: WhenType.someday.value);
      await insertTask(id: 'b', whenType: WhenType.none.value);
      await insertTask(id: 'c', whenType: WhenType.someday.value, status: 1);

      final tasks = await db.watchSomedayTasks().first;
      expect(tasks.map((t) => t.id).toSet(), {'a'});
    });

  });

  group('watchFutureTasks', () {
    test('returns tasks with dueDate strictly after today; excludes past/today/no-date/done',
        () async {
      // 未来日期：包含
      await insertTask(
        id: 'tomorrow',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.add(const Duration(days: 1)),
      );
      await insertTask(
        id: 'next_week',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.add(const Duration(days: 7)),
      );
      // 今天：排除
      await insertTask(
        id: 'today',
        whenType: WhenType.today.value,
        dueDate: startOfToday,
      );
      // 过去：排除
      await insertTask(
        id: 'yesterday',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.subtract(const Duration(days: 1)),
      );
      // 无日期：排除
      await insertTask(id: 'undated', whenType: WhenType.none.value);
      // 已完成：排除
      await insertTask(
        id: 'done',
        whenType: WhenType.scheduled.value,
        dueDate: startOfToday.add(const Duration(days: 3)),
        status: 1,
        completedAt: now,
      );

      final tasks = await db.watchFutureTasks().first;
      // 升序：tomorrow 先于 next_week
      expect(tasks.map((t) => t.id).toList(), ['tomorrow', 'next_week']);
    });
  });

  group('watchLogbook', () {
    test('returns done tasks within window, ordered by completedAt desc',
        () async {
      await insertTask(
        id: 'old',
        status: 1,
        completedAt: now.subtract(const Duration(days: 100)),
      );
      await insertTask(
        id: 'recent1',
        status: 1,
        completedAt: now.subtract(const Duration(days: 5)),
      );
      await insertTask(
        id: 'recent2',
        status: 1,
        completedAt: now.subtract(const Duration(days: 10)),
      );
      // hidden from logbook
      await insertTask(
        id: 'hidden',
        status: 1,
        completedAt: now.subtract(const Duration(days: 1)),
        inLogbook: false,
      );
      // unfinished
      await insertTask(id: 'todo');

      final tasks = await db.watchLogbook(days: 90).first;
      expect(tasks.map((t) => t.id).toList(), ['recent1', 'recent2']);
    });
  });

  group('Areas / Projects / Headings / Checklists', () {
    test('insertArea + watchAreas: order by sortOrder', () async {
      final a = await db.insertArea('Work');
      final b = await db.insertArea('Life');
      final list = await db.watchAreas().first;
      expect(list.map((x) => x.id).toList(), [a, b]);
      expect(list.first.sortOrder, 0);
      expect(list.last.sortOrder, 1);
    });

    test('reorderAreas overrides sortOrder', () async {
      final a = await db.insertArea('A');
      final b = await db.insertArea('B');
      final c = await db.insertArea('C');
      await db.reorderAreas([c, a, b]);
      final list = await db.watchAreas().first;
      expect(list.map((x) => x.id).toList(), [c, a, b]);
    });

    test('watchProjectsByArea: null vs specific', () async {
      // onCreate seeds 'work'/'personal' (no areaId) — keep them alive.
      final areaId = await db.insertArea('Office');
      final projId = await db.createProject('Project Z', '#FF112233');
      // attach Project Z to areaId
      await (db.update(db.projects)..where((p) => p.id.equals(projId))).write(
        ProjectsCompanion(areaId: Value(areaId)),
      );

      final inArea = await db.watchProjectsByArea(areaId).first;
      expect(inArea.map((p) => p.id), contains(projId));

      final unattached = await db.watchProjectsByArea(null).first;
      expect(unattached.map((p) => p.id), contains('work'));
      expect(unattached.map((p) => p.id), contains('personal'));
      expect(unattached.map((p) => p.id), isNot(contains(projId)));
    });

    test('Headings: archived excluded, ordered by sortOrder', () async {
      final h1 = await db.insertHeading('work', 'Q1');
      final h2 = await db.insertHeading('work', 'Q2');
      await db.archiveHeading(h1);
      final list = await db.watchHeadings('work').first;
      expect(list.map((h) => h.id).toList(), [h2]);
    });

    test('Checklist: insert + toggle + reorder', () async {
      // 任务必须存在以满足将来 FK；测试中 Drift 在内存里没启用 FK 强制，
      // 但出于真实路径考虑，我们插一条父任务。
      await insertTask(id: 'parent', title: 'Parent');

      final c1 = await db.insertChecklistItem('parent', 'Step 1');
      final c2 = await db.insertChecklistItem('parent', 'Step 2');
      final c3 = await db.insertChecklistItem('parent', 'Step 3');

      var items = await db.watchChecklist('parent').first;
      expect(items.map((c) => c.title).toList(), ['Step 1', 'Step 2', 'Step 3']);

      await db.toggleChecklistItem(c2, true);
      items = await db.watchChecklist('parent').first;
      expect(items.firstWhere((c) => c.id == c2).isChecked, isTrue);

      await db.reorderChecklist([c3, c1, c2]);
      items = await db.watchChecklist('parent').first;
      expect(items.map((c) => c.id).toList(), [c3, c1, c2]);
    });
  });

  group('watchProjectProgress', () {
    test('counts done/total for a project', () async {
      await insertTask(id: 'a', projectId: 'work', status: 0);
      await insertTask(id: 'b', projectId: 'work', status: 1);
      await insertTask(id: 'c', projectId: 'work', status: 1);
      // deleted does not count
      await insertTask(id: 'd', projectId: 'work', status: 2);
      // other project
      await insertTask(id: 'e', projectId: 'personal', status: 0);

      final progress = await db.watchProjectProgress('work').first;
      expect(progress.total, 3);
      expect(progress.done, 2);
    });
  });

  group('watchTasksByHeading', () {
    test('filters by heading and ignores subtasks', () async {
      final headingId = await db.insertHeading('work', 'Sprint');
      await insertTask(id: 'a', projectId: 'work', headingId: headingId);
      await insertTask(id: 'b', projectId: 'work', headingId: headingId);
      // subtask under a → filtered out
      await insertTask(id: 'sub', projectId: 'work', parentId: 'a');
      // task in same project but no heading → not in
      await insertTask(id: 'orphan', projectId: 'work');

      final tasks = await db.watchTasksByHeading(headingId).first;
      expect(tasks.map((t) => t.id).toSet(), {'a', 'b'});
    });
  });

  group('color hex helpers', () {
    test('createProject + watchProjects round-trips hex', () async {
      final id = await db.createProject('Z', '#FF112233');
      final list = await db.watchProjects().first;
      final p = list.firstWhere((p) => p.id == id);
      expect(p.color, '#FF112233');
    });

    test('createProject 接受 null（沿用主题默认）', () async {
      final id = await db.createProject('No color', null);
      final list = await db.watchProjects().first;
      final p = list.firstWhere((p) => p.id == id);
      expect(p.color, isNull);
    });
  });
}
