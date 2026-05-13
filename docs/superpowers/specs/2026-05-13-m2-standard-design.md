# FlowLog M2 标准版设计

## 目标

M2 标准版把 M1 已接好的自适应 Shell 补成可用的 Things 风格任务体验。
它主要修复 `AdaptiveShell` 替换旧 `HomePage` 后留下的功能入口缺口，并统一
核心列表视图的交互与视觉，但不提前引入 M3 的复杂交互。

## 范围

M2 包含：

- Sidebar 动态显示 Areas、Projects、Tags。
- Project 行显示颜色/图标、未完成任务数和进度。
- Quick Find 接入 `Cmd+K`，支持搜索固定视图、任务、项目和标签。
- Quick Add 按当前上下文创建任务：Inbox、Today、Project、Tag。
- Today 改用 `watchTodayWithEvening()`，分为 Overdue、Today、This Evening。
- Calendar 保留现有日期分组模型，但视觉统一到 M2 列表样式。
- Future/Someday、Logbook、Project、Tag 页面改成统一的 M2 列表壳和空状态。
- TaskRow 统一样式，保留完成勾选、打开详情、日期/截止日期标记、重复标记、标签和现有右键优先级菜单。
- 桌面端点击任务行继续选中右侧 DetailPane；手机和平板继续弹出详情 sheet。

M2 不包含：

- 拖拽排序。
- 多选和批量操作。
- Markdown notes。
- Checklist 编辑 UI。
- AI 工作流重构。
- 超出现有 AI 解析能力的自然语言日期解析。
- 服务端同步、设备配对或冲突处理。

## 方案

采用“共享列表基础设施 + 逐页替换”的方案，而不是在每个页面里各自重写。
各页面只负责提供数据流、标题、分组规则和 Quick Add 上下文；共享组件负责
列表布局、行样式、分组标题和空状态。

这样 M2 可以小步落地，也为 M3 的拖拽、多选和 Checklist UI 留出统一接入点。

## 组件

新增共享组件目录：`client/lib/ui/m2/`。

- `task_list_scaffold.dart`：通用页面壳，负责标题、副标题、可选 Quick Add、滚动 padding、加载态、错误态和空状态。
- `task_quick_add_bar.dart`：单行任务创建组件。接收 `QuickAddContext`，按当前视图写入正确字段。
- `task_section.dart`：分组标题和分组任务列表。
- `m2_task_row.dart`：所有 M2 页面共用的任务行。
- `task_empty_state.dart`：统一的图标 + 文案空状态。

修改现有 Shell 和页面：

- `client/lib/ui/shell/sidebar.dart`：在固定视图下面渲染 Areas -> Projects、独立 Projects 和 Tags。
- `client/lib/ui/shell/quick_find.dart`：搜索固定视图、任务、项目、标签，并执行对应跳转或打开详情。
- `client/lib/ui/shell/adaptive_shell.dart`：包一层 Shortcuts / Actions，让 `Cmd+K` 打开 Quick Find。
- `client/lib/ui/shell/shell_content.dart`：统一处理 Area、Project、Tag 的选中路由。
- `client/lib/ui/today/today_page.dart`：使用 M2 页面壳和 `watchTodayWithEvening()`。
- `client/lib/ui/inbox/inbox_page.dart`：使用 M2 页面壳和 Inbox Quick Add 上下文。
- `client/lib/ui/upcoming/upcoming_page.dart`：保留现有分组行为，但换成 M2 任务行和分组样式。
- `client/lib/ui/someday/someday_page.dart`：保留当前用户偏好，即该入口表示未来日期任务，并使用 M2 页面壳。
- `client/lib/ui/logbook/logbook_page.dart`：按月份分组展示已完成任务。
- `client/lib/ui/projects/project_page.dart`：使用 M2 页面壳、项目进度和 Project Quick Add。
- `client/lib/ui/tags/tag_page.dart`：使用 M2 页面壳和 Tag Quick Add。

## 数据流

Sidebar：

1. 固定视图继续使用 `SelectionStore.selectView`。
2. Areas 来自 `AppDatabase.watchAreas()`。
3. Projects 来自每个 Area 的 `watchProjectsByArea(areaId)`，以及 `areaId == null` 的独立项目分组。
4. Tags 来自 `watchTags()`。
5. 点击 Project 或 Tag 后更新 SelectionStore，由 `ShellContent` 渲染对应页面。

Quick Find：

1. 空 query 显示固定视图和最近导航项。
2. 非空 query 合并这些结果：
   - Shell 固定视图标签；
   - `watchTasksByKeyword(query)` 返回的活动任务；
   - `watchProjects()` 返回的项目；
   - `watchTags()` 返回的标签。
3. 选择任务时，桌面端打开 DetailPane，手机和平板打开详情 sheet。
4. 选择项目或标签时更新 `SelectionStore`；选择 Settings 或 Trash 时沿用现有 `Navigator.push`。

Quick Add：

`QuickAddContext` 决定写入规则：

- Inbox：创建无项目、无 when 的活动任务。
- Today：创建 `whenType=today` 且日期为今天的活动任务。
- Project：创建带当前 `projectId` 的活动任务。
- Tag：先创建任务，再用 `setTagsForTask` 绑定当前标签。
- Calendar/Future：M2 先创建到 Inbox；指定日期创建留给 M3 或 AI 解析。
- Logbook：不显示 Quick Add。

## 视觉行为

M2 使用安静、工作型的界面风格：

- 不做嵌套卡片。
- 列表直接落在页面 surface 上，使用克制分隔线。
- Header 紧凑、可扫读。
- TaskRow 尺寸稳定，hover 不改变布局。
- Project 进度保持轻量：计数文本 + 小型圆形进度或等价紧凑视觉。
- 空状态保持简洁，不写营销或教学式文案。

## 错误处理

- Stream 错误在对应列表区域内联显示。
- Quick Add 输入为空时不写库。
- Tag Quick Add 如果任务创建后绑定标签失败，任务保留在 Inbox，并显示临时错误提示。
- 选中的 Project 或 Tag 已不存在时，显示现有 not-found 空状态。

## 测试

实现前先补或更新 Flutter 测试：

- `client/test/ui/shell_navigation_test.dart`
  - Sidebar 能显示 Areas、Projects、独立 Projects 和 Tags。
  - 点击 Project / Tag 会更新 SelectionStore 状态。
- `client/test/ui/quick_find_test.dart`
  - `Cmd+K` 能打开 Quick Find。
  - query 能匹配固定视图、任务、项目和标签。
  - 选择 Project / Tag / Task 会执行正确动作。
- `client/test/ui/quick_add_test.dart`
  - Inbox Quick Add 写入无安排任务。
  - Today Quick Add 写入 `whenType=today`。
  - Project Quick Add 写入 `projectId`。
  - Tag Quick Add 绑定当前标签。
- `client/test/database/queries_test.dart`
  - Today 能分出 overdue、today、evening。
  - Project progress 返回 done 和 total。
  - Area / Project 排序符合 `sortOrder` 优先、name 次之。

完成标准：

- 目标测试通过。
- 全量 `flutter test` 通过。
- `flutter analyze --no-pub` 无 error。

## 落地顺序

M2 按小提交落地：

1. 共享 M2 列表组件。
2. Sidebar 动态导航。
3. Quick Find 和 `Cmd+K`。
4. Quick Add 上下文。
5. 核心页面替换。
6. 测试和进度文档更新。

M2 完成后更新 `flowlog_design/refactor/PROGRESS.md`。
