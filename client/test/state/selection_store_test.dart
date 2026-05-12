import 'package:flowlog_client/state/selection_store.dart';
import 'package:flowlog_client/ui/shell/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectionStore', () {
    test('default state is Today', () {
      final store = SelectionStore();
      expect(store.state.view, SidebarView.today);
      expect(store.state.entityId, isNull);
      expect(store.state.selectedTaskId, isNull);
    });

    test('selectView 切视图时清掉 selectedTaskId（避免 DetailPane 渲染上一个视图的任务）',
        () {
      final store = SelectionStore(
        initial: const SelectionState(
          view: SidebarView.today,
          selectedTaskId: 'task-a',
        ),
      );
      store.selectView(SidebarView.inbox);
      expect(store.state.view, SidebarView.inbox);
      expect(store.state.selectedTaskId, isNull);
    });

    test('selectView 同 view + 同 entityId 不发 notify', () {
      final store = SelectionStore(
        initial: const SelectionState(
          view: SidebarView.project,
          entityId: 'p1',
        ),
      );
      var calls = 0;
      store.addListener(() => calls++);
      store.selectView(SidebarView.project, entityId: 'p1');
      expect(calls, 0);
    });

    test('selectTask 写入 / clearTask 清空，且只在变化时 notify', () {
      final store = SelectionStore();
      var calls = 0;
      store.addListener(() => calls++);

      store.selectTask('task-1');
      expect(store.state.selectedTaskId, 'task-1');
      expect(calls, 1);

      store.selectTask('task-1');
      expect(calls, 1, reason: '相同任务 ID 不应再次 notify');

      store.selectTask('task-2');
      expect(store.state.selectedTaskId, 'task-2');
      expect(calls, 2);

      store.clearTask();
      expect(store.state.selectedTaskId, isNull);
      expect(calls, 3);
    });

    test('SelectionState.copyWith 用 sentinel 区分"不传"和"显式 null"', () {
      const a = SelectionState(
        view: SidebarView.project,
        entityId: 'p1',
        selectedTaskId: 'task-x',
      );
      // 不传：保留旧值
      final b = a.copyWith();
      expect(b, a);

      // 显式 null：清空
      final c = a.copyWith(selectedTaskId: null);
      expect(c.view, SidebarView.project);
      expect(c.entityId, 'p1');
      expect(c.selectedTaskId, isNull);

      // 改 view 时其他字段保留（除非显式覆盖）
      final d = a.copyWith(view: SidebarView.today);
      expect(d.view, SidebarView.today);
      expect(d.entityId, 'p1');
      expect(d.selectedTaskId, 'task-x');
    });
  });

  group('layoutForWidth', () {
    test('< 600 → mobile', () {
      expect(layoutForWidth(0), ShellLayout.mobile);
      expect(layoutForWidth(599.99), ShellLayout.mobile);
    });
    test('600..1000 → tablet', () {
      expect(layoutForWidth(600), ShellLayout.tablet);
      expect(layoutForWidth(999.99), ShellLayout.tablet);
    });
    test('≥ 1000 → desktop（task_row 在此分支才走 SelectionStore.selectTask）', () {
      expect(layoutForWidth(1000), ShellLayout.desktop);
      expect(layoutForWidth(1920), ShellLayout.desktop);
    });
  });
}
