# M1-04 自适应 Shell（三档断点 + Sidebar + DetailPane）

> 重写应用顶层壳，按屏幕宽度分发到 Mobile / Tablet / Desktop 三档布局。Sidebar 与 DetailPane 单独成组件，旧 `home_page.dart` 暂保留并嵌入新 Shell 内，等 M2 替换。

## 1. 目标

- 同一份代码在 iPhone / iPad / Android 手机 / Android 平板 / macOS 上分别呈现合适布局。
- 提供 `SelectionStore` 统一管理"当前侧边栏选中"与"当前选中任务"，让 DetailPane 与各 list 解耦。
- M1 阶段不重写视图层，旧 `today_page.dart` / `inbox_page.dart` / `upcoming_page.dart` 仍然挂在 Shell 内，能跑。

## 2. 现状

`client/lib/ui/home/home_page.dart`（约 1300 行）：
- 自绘 Sidebar 写死在文件内
- 用 `LayoutBuilder` 800px 一刀切（desktop / mobile）
- `IndexedStack` 切换内容
- 详情面板逻辑通过 `showModalBottomSheet` 实现，桌面与手机一致

问题：
- Sidebar 与内容耦合，无法在不同 Shell 中复用
- 没有 tablet 中间档（双栏）
- 桌面端缺右侧常驻 DetailPane
- 没有可拖动分隔条

## 3. 断点定义

文件：`client/lib/ui/shell/breakpoints.dart`

```dart
class FlowBreakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 1000;
  // < 600     → MobileShell  (单栏 + 底部 Tab)
  // 600-1000  → TabletShell  (双栏: NavigationRail + Content)
  // ≥ 1000    → DesktopShell (三栏: Sidebar + List + Detail)
}

enum ShellLayout { mobile, tablet, desktop }

ShellLayout layoutForWidth(double w) {
  if (w < FlowBreakpoints.mobileMax) return ShellLayout.mobile;
  if (w < FlowBreakpoints.tabletMax) return ShellLayout.tablet;
  return ShellLayout.desktop;
}
```

## 4. 文件结构

```
client/lib/ui/shell/
├── breakpoints.dart
├── adaptive_shell.dart        # 顶层 LayoutBuilder
├── mobile_shell.dart          # < 600
├── tablet_shell.dart          # 600-1000
├── desktop_shell.dart         # ≥ 1000
├── sidebar.dart               # tablet/desktop 共用
├── sidebar_item.dart
├── detail_pane.dart           # desktop 专用
└── shell_scaffold.dart        # 各 Shell 共享的顶部栏 / 状态栏

client/lib/state/
└── selection_store.dart        # 全局选中状态（ChangeNotifier）
```

## 5. 关键类设计

### 5.1 SelectionStore

`client/lib/state/selection_store.dart`：

```dart
enum SidebarView {
  inbox, today, upcoming, anytime, someday, logbook,
  area,    // 配合 areaId
  project, // 配合 projectId
  tag,     // 配合 tagId
  search, settings, trash,
}

class SelectionState {
  final SidebarView view;
  final String? entityId;   // areaId / projectId / tagId
  final String? selectedTaskId;
  const SelectionState({required this.view, this.entityId, this.selectedTaskId});
  SelectionState copyWith({...});
}

class SelectionStore extends ChangeNotifier {
  SelectionState _state = const SelectionState(view: SidebarView.today);
  SelectionState get state => _state;

  void selectView(SidebarView view, {String? entityId}) { ... }
  void selectTask(String? taskId) { ... }
  void clearTask() { ... }
}
```

注入：`main.dart` 用 `Provider<SelectionStore>` 顶层提供。

### 5.2 AdaptiveShell

`client/lib/ui/shell/adaptive_shell.dart`：

```dart
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (layoutForWidth(constraints.maxWidth)) {
          case ShellLayout.mobile:  return const MobileShell();
          case ShellLayout.tablet:  return const TabletShell();
          case ShellLayout.desktop: return const DesktopShell();
        }
      },
    );
  }
}
```

### 5.3 MobileShell

`mobile_shell.dart`：

```dart
class MobileShell extends StatelessWidget {
  static const _tabs = [
    SidebarView.today,
    SidebarView.upcoming,
    SidebarView.anytime,
    SidebarView.inbox,
    SidebarView.project,   // 跳到 Projects 列表
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SelectionStore>();
    final index = _tabs.indexOf(store.state.view).clamp(0, _tabs.length - 1);

    return Scaffold(
      body: SafeArea(child: _buildContent(store.state)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today),    label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Upcoming'),
          NavigationDestination(icon: Icon(Icons.layers),   label: 'Anytime'),
          NavigationDestination(icon: Icon(Icons.inbox),    label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.folder),   label: 'Projects'),
        ],
        onDestinationSelected: (i) => context.read<SelectionStore>().selectView(_tabs[i]),
      ),
    );
  }
}
```

任务详情：mobile 走 `Navigator.push(MaterialPageRoute(builder: ...))` 进入全屏 Detail 页。

### 5.4 TabletShell

`tablet_shell.dart`：

```dart
class TabletShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 280, child: const Sidebar()),
          const VerticalDivider(width: 1),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }
}
```

任务详情：tablet 走 modal sheet 或全屏 push（与 mobile 一致），不开常驻 Detail。

### 5.5 DesktopShell

`desktop_shell.dart`：

```dart
class DesktopShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final selection = context.watch<SelectionStore>();
    final showDetail = selection.state.selectedTaskId != null;

    return Scaffold(
      body: MultiSplitView(
        controller: MultiSplitViewController(
          areas: [
            Area(weight: 0.20, minimalWeight: 0.15),
            Area(weight: showDetail ? 0.45 : 0.80),
            if (showDetail) Area(weight: 0.35, minimalWeight: 0.25),
          ],
        ),
        children: [
          const Sidebar(),
          _buildContent(context),
          if (showDetail) const DetailPane(),
        ],
      ),
    );
  }
}
```

依赖：`pubspec.yaml` 加 `multi_split_view: ^3.0.0`。

### 5.6 Sidebar

`sidebar.dart`：

```dart
class Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final selection = context.watch<SelectionStore>();
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 顶部固定项
          SidebarItem(view: SidebarView.inbox,    icon: Icons.inbox,    label: 'Inbox'),
          SidebarItem(view: SidebarView.today,    icon: Icons.star,     label: 'Today'),
          SidebarItem(view: SidebarView.upcoming, icon: Icons.calendar_month, label: 'Upcoming'),
          SidebarItem(view: SidebarView.anytime,  icon: Icons.layers,   label: 'Anytime'),
          SidebarItem(view: SidebarView.someday,  icon: Icons.archive,  label: 'Someday'),
          SidebarItem(view: SidebarView.logbook,  icon: Icons.checklist, label: 'Logbook'),
          const Divider(),
          // 动态：Areas → Projects（M1 仅占位，M2 实装）
          // ... StreamBuilder<List<Area>> ...
          const Divider(),
          SidebarItem(view: SidebarView.trash,    icon: Icons.delete_outline, label: 'Trash'),
          SidebarItem(view: SidebarView.settings, icon: Icons.settings, label: 'Settings'),
        ],
      ),
    );
  }
}
```

Areas / Projects 动态部分 M1 阶段挂个 `// TODO M2`，先把固定 6 项跑通。

### 5.7 DetailPane

`detail_pane.dart`：

```dart
class DetailPane extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final taskId = context.watch<SelectionStore>().state.selectedTaskId;
    if (taskId == null) {
      return const _EmptyDetail();   // "选择一个任务查看详情"
    }
    return TaskDetailView(taskId: taskId);   // 复用现有 TaskDetailPage 组件，去掉 Scaffold 包装
  }
}
```

> M1 阶段从 `client/lib/ui/task_detail/` 抽出一个不含 `Scaffold` 的 `TaskDetailView`，让 `DetailPane`（嵌入式）和 mobile 全屏页都能复用。

## 6. main.dart 接入

文件：`client/lib/main.dart`

```dart
import 'package:flowlog/state/selection_store.dart';
import 'package:flowlog/ui/shell/adaptive_shell.dart';
import 'package:flowlog/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ...已有初始化...

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(create: (_) => db),
        ChangeNotifierProvider<AppSettings>(create: (_) => settings),
        ChangeNotifierProvider<SelectionStore>(create: (_) => SelectionStore()),
        // ...
      ],
      child: DynamicColorBuilder(
        builder: (light, dark) => MaterialApp(
          theme: appLightTheme(seed: light?.primary),
          darkTheme: appDarkTheme(seed: dark?.primary),
          themeMode: ThemeMode.system,
          home: settings.onboardingCompleted
              ? const AdaptiveShell()
              : const OnboardingPage(),
        ),
      ),
    ),
  );
}
```

旧的 `HomePage` 不删，标记 `@Deprecated('Use AdaptiveShell, will be removed in M2')`，便于回滚。

## 7. 旧视图复用

各 Shell 的 `_buildContent(state)`：

```dart
Widget _buildContent(BuildContext context) {
  final s = context.watch<SelectionStore>().state;
  switch (s.view) {
    case SidebarView.today:    return const TodayPage();    // 旧
    case SidebarView.inbox:    return const InboxPage();    // 旧
    case SidebarView.upcoming: return const UpcomingPage(); // 旧
    case SidebarView.anytime:  return const AnytimePage();  // M1 占位
    case SidebarView.someday:  return const SomedayPage();  // M1 占位
    case SidebarView.logbook:  return const LogbookPage();  // M1 占位
    case SidebarView.project:  return ProjectPage(id: s.entityId!);
    // ...
  }
}
```

M1 占位页内容：
```dart
class AnytimePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Anytime — coming in M2'));
}
```

## 8. 动画与无障碍

- 三档切换不要做 `AnimatedSwitcher`，直接重建即可（窗口 resize 时减少抖动）。
- Sidebar 项有 hover 高亮（桌面）/ press 涟漪（移动）。
- 所有 `SidebarItem` 需要 `Semantics(label: ..., button: true)`。
- 桌面键盘焦点：`FocusTraversalGroup` + 上下键切换 sidebar 项（M3 完善）。

## 9. 文件清单

### 新增
```
client/lib/ui/shell/breakpoints.dart
client/lib/ui/shell/adaptive_shell.dart
client/lib/ui/shell/mobile_shell.dart
client/lib/ui/shell/tablet_shell.dart
client/lib/ui/shell/desktop_shell.dart
client/lib/ui/shell/sidebar.dart
client/lib/ui/shell/sidebar_item.dart
client/lib/ui/shell/detail_pane.dart
client/lib/ui/shell/shell_scaffold.dart
client/lib/state/selection_store.dart
client/lib/ui/anytime/anytime_page.dart        # 占位
client/lib/ui/someday/someday_page.dart        # 占位
client/lib/ui/logbook/logbook_page.dart        # 占位
```

### 修改
```
client/lib/main.dart                            # 接入 AdaptiveShell + SelectionStore + DynamicColorBuilder
client/lib/ui/home/home_page.dart               # 标记 deprecated（M2 删）
client/lib/ui/task_detail/<...>.dart            # 抽出 TaskDetailView（不含 Scaffold）
client/pubspec.yaml                             # multi_split_view
```

## 10. 实施步骤

1. `feat(state): SelectionStore + SidebarView enum`
2. `feat(shell): breakpoints + AdaptiveShell skeleton`（先空壳，三档都返回 `Placeholder`）
3. `feat(shell): MobileShell with bottom NavigationBar wired to old pages`
4. `feat(shell): Sidebar widget + 6 fixed items`
5. `feat(shell): TabletShell two-pane`
6. `feat(shell): DesktopShell three-pane via multi_split_view`
7. `refactor(detail): extract TaskDetailView for embed reuse`
8. `feat(shell): DesktopShell wires DetailPane on selectionStore.selectedTaskId`
9. `feat(pages): Anytime/Someday/Logbook placeholders`
10. `chore(home): mark old HomePage deprecated`

## 11. 风险与注意事项

| 风险 | 应对 |
|---|---|
| `multi_split_view` 在窄屏崩溃 | 在 DesktopShell 内置 `if (width < 1000) fallback to TabletShell`，作 belt-and-suspenders |
| 旧 BottomSheet 详情与新 DetailPane 双行为 | mobile/tablet 仍走 modal，desktop 走嵌入；通过 `selectionStore.selectTask` 在 desktop 触发，mobile/tablet 直接 `Navigator.push` |
| iPad 旋转时 layout 闪烁 | `AdaptiveShell` 是 `StatelessWidget`，不持有 state；`SelectionStore` 是全局 ChangeNotifier，不会因 layout 切换丢失 |
| Sidebar 滚动与内容滚动冲突 | Sidebar 用 `ListView`，外层 `Container` 不要套 `Scrollable` |
| 旧 `HomePage` 与 `AdaptiveShell` 双存导致 import 混乱 | M1 期间 `main.dart` 只引用 AdaptiveShell；旧 HomePage 仅通过 git 历史可访问 |
| Provider scope 遗漏 | 顶层 `MultiProvider` 包 `MaterialApp`，不要在 Shell 内重复创建 SelectionStore |

## 12. 验收标准

1. ✅ macOS 窗口宽度 500 / 800 / 1200 三种宽度下，分别看到底部 Tab / 双栏 / 三栏。
2. ✅ 拖动 macOS 窗口宽度跨越 600 / 1000 边界，布局切换无报错。
3. ✅ iPad 模拟器横竖屏切换：横屏三栏，竖屏双栏。
4. ✅ iPhone 模拟器：底部 Tab 5 项可切换，点击任务全屏 push 详情。
5. ✅ 桌面三栏下，点击列表中任务，右侧 DetailPane 立即更新。
6. ✅ Sidebar 中 6 个固定项点击切换正常，旧 Today/Inbox/Upcoming 内容正常显示。
7. ✅ M1 占位页（Anytime / Someday / Logbook）显示 placeholder 文案。
