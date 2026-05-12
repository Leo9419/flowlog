import 'package:flutter/foundation.dart';

/// 侧边栏 / Shell 中可被选中的"视图"枚举。
///
/// 与 `M1_04_Adaptive_Shell.md` §5.1 保持一致；M2 视图重构会针对每一项
/// 实装真实页面，M1 阶段一部分（today/inbox/upcoming）复用旧页面，其余
/// （anytime/someday/logbook）走占位页。
enum SidebarView {
  inbox,
  today,
  upcoming,
  anytime,
  someday,
  logbook,
  ai,

  /// Sidebar 中点击某个 Area；[SelectionState.entityId] = areaId
  area,

  /// 点击某个 Project；entityId = projectId
  project,

  /// 点击某个 Tag；entityId = tagId
  tag,

  search,
  settings,
  trash,
}

/// 不可变的全局选中态。
///
/// 三元组：当前侧边栏视图 + 实体 ID（可选）+ 当前选中任务（可选）。
/// `selectedTaskId` 是为 desktop 三栏 DetailPane 准备的；mobile/tablet
/// 在打开任务详情时直接 `Navigator.push`，不修改这里。
@immutable
class SelectionState {
  const SelectionState({
    required this.view,
    this.entityId,
    this.selectedTaskId,
  });

  final SidebarView view;
  final String? entityId;
  final String? selectedTaskId;

  SelectionState copyWith({
    SidebarView? view,
    Object? entityId = _sentinel,
    Object? selectedTaskId = _sentinel,
  }) {
    return SelectionState(
      view: view ?? this.view,
      entityId:
          identical(entityId, _sentinel) ? this.entityId : entityId as String?,
      selectedTaskId: identical(selectedTaskId, _sentinel)
          ? this.selectedTaskId
          : selectedTaskId as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SelectionState &&
      other.view == view &&
      other.entityId == entityId &&
      other.selectedTaskId == selectedTaskId;

  @override
  int get hashCode => Object.hash(view, entityId, selectedTaskId);

  @override
  String toString() =>
      'SelectionState(view=$view, entityId=$entityId, taskId=$selectedTaskId)';
}

const _sentinel = Object();

/// 全局选中态 store。
///
/// 由 main.dart 顶层 `ChangeNotifierProvider<SelectionStore>` 提供，
/// Sidebar / 内容列表 / DetailPane 都通过 `Provider.of` / `context.watch`
/// 订阅与触发。
class SelectionStore extends ChangeNotifier {
  SelectionStore({SelectionState? initial})
      : _state = initial ?? const SelectionState(view: SidebarView.today);

  SelectionState _state;
  SelectionState get state => _state;

  /// 切换视图；切换视图时清掉之前选中的任务，避免 Detail 显示陈旧数据。
  void selectView(SidebarView view, {String? entityId}) {
    final next = SelectionState(
      view: view,
      entityId: entityId,
      selectedTaskId: null,
    );
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  /// 选中（或清空）当前任务；只用于 desktop 三栏。
  void selectTask(String? taskId) {
    if (_state.selectedTaskId == taskId) return;
    _state = _state.copyWith(selectedTaskId: taskId);
    notifyListeners();
  }

  void clearTask() => selectTask(null);
}
