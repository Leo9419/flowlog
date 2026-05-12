# 区域与项目功能设计

> 目标：把 Flowlog 当前的“清单”升级为 Things 风格的 **Area > Project > Heading > Task** 组织结构。
> 本文聚焦功能设计与落地边界；底层表结构已在 `refactor/M1_01_Data_Model.md` 中完成预留。

## 1. 概念定义

### 1.1 Area（区域）

Area 是长期持续维护的责任范围，例如“工作”“家庭”“健康”“学习”。

产品语义：

- 区域本身没有完成状态，不进入 Logbook。
- 区域不直接承载任务，只承载 Project。
- 区域主要用于侧边栏分组、统计汇总和 AI 报告维度。
- 区域可以折叠、排序、重命名、删除。

删除语义：

- 删除区域时不删除项目和任务。
- 区域下的项目统一变为“未归属区域”的独立项目，即 `projects.area_id = NULL`。
- 后续同步版本可把删除改为软删除；M2 本地功能先按解除归属处理。

### 1.2 Project（项目）

Project 是有明确完成标准的一组任务，例如“上线 Flowlog v1”“办签证”“完成年度体检”。

产品语义：

- 项目可以属于某个 Area，也可以独立存在。
- 项目可包含 Heading 和 Task。
- 项目有进度、状态、完成时间、截止日和备注。
- 项目完成后，其未完成任务需要用户确认处理。

项目状态：

| 状态 | 字段 | 含义 |
|---|---|---|
| Active | `status=0` | 默认，侧边栏显示 |
| Completed | `status=1` | 项目完成，进入项目归档/Logbook 维度 |
| Cancelled | `status=2` | 项目取消，不再作为活跃项目显示 |
| Deleted | `status=3` | 软删除，进入 Trash 或同步删除队列 |

### 1.3 Heading（项目分节）

Heading 是项目内的章节标题，例如“设计”“开发”“发布前检查”。

产品语义：

- Heading 不是任务，不进入 Today / Upcoming / Anytime。
- Heading 只在 Project 详情页内显示。
- Heading 可排序、重命名、归档。
- Heading 下的任务仍然是普通 Task，通过 `tasks.heading_id` 关联。

## 2. 信息架构

### 2.1 Sidebar 结构

桌面和平板 Sidebar 在固定视图后展示动态区域：

```text
Inbox
Today
Calendar
Someday
Logbook

Areas & Projects
  工作
    Flowlog v1
    官网改版
  生活
    年度体检
  独立项目
    读完一本书

Trash
Settings
```

规则：

- Area 可折叠，折叠状态存在本地 UI 偏好中，不同步。
- 未归属 Area 的项目显示在“独立项目”分组。
- 无项目的 Area 仍显示，方便用户拖入或新建项目。
- 项目行显示名称、颜色/图标、未完成任务数、进度环。
- 选中 Area 进入 Area 视图；选中 Project 进入 Project 视图。

### 2.2 移动端入口

移动端底部 Tab 保持高频视图，项目体系从 Projects 页进入：

- 顶部显示 Areas 列表与“独立项目”。
- 点击 Area 进入区域页。
- 点击 Project 进入项目页。
- 新建按钮提供“新建区域”和“新建项目”两个动作。

## 3. 视图设计

### 3.1 Area 视图

Area 视图用于查看一个责任范围下的所有项目。

内容：

- 标题：Area 名称和图标。
- 操作：重命名、换图标、删除区域、新建项目。
- 项目列表：按 `projects.sort_order` 排序。
- 每个项目卡/行显示：
  - 项目名
  - 进度 `done / total`
  - deadline 徽标
  - today/upcoming 任务数量摘要

空状态：

- 文案：`暂无项目`
- 主操作：`新建项目`

### 3.2 Project 视图

Project 视图是项目任务的主工作区。

内容：

- 标题区：项目名、颜色/图标、所属区域、进度环。
- 项目元信息：deadline、notes、状态。
- Quick Add：默认写入当前 `project_id`；如果光标位于 Heading 下，同时写入 `heading_id`。
- Heading 分节：按 `headings.sort_order` 展示。
- 未分节任务：显示在 Heading 前或“无分节”区域，M2 建议放在 Heading 之前。

排序：

- 项目内默认使用手动排序：`heading_id ASC`, `tasks.sort_order ASC`, `created_at ASC`。
- 用户切换创建时间/截止日/优先级排序时只改变显示，不修改 `sort_order`。

完成项目：

- 点击“完成项目”时弹确认：
  - 若所有任务已完成：直接把 `projects.status=1`，写入 `completed_at`。
  - 若仍有未完成任务：提供“同时完成任务”“保留任务并移到 Inbox”“取消”。

## 4. 创建与编辑流程

### 4.1 新建区域

入口：

- Sidebar 的 Areas & Projects 标题右侧 `+`
- Projects 管理页
- Project 编辑弹窗中的“新建区域”

字段：

- 名称，必填。
- 图标，可选。

写入：

- `areas.id = uuid`
- `areas.name`
- `areas.icon_name`
- `areas.sort_order = 当前最大值 + 1`
- `is_dirty = true`

### 4.2 新建项目

入口：

- Area 视图顶部。
- Sidebar 区域右侧菜单。
- Projects 管理页。
- Quick Find 命令。

字段：

- 名称，必填。
- Area，可选；从某个 Area 新建时默认选中该 Area。
- 颜色/图标，可选。
- Deadline，可选。
- Notes，可选。

写入：

- `projects.id = uuid`
- `projects.name`
- `projects.area_id`
- `projects.color`
- `projects.icon_name`
- `projects.deadline`
- `projects.notes`
- `projects.status = 0`
- `projects.sort_order = 当前 area 下最大值 + 1`
- `is_dirty = true`

### 4.3 移动项目到区域

入口：

- 项目编辑弹窗中的 Area picker。
- Sidebar 拖拽项目到 Area。
- Area 视图项目菜单。

写入：

- `projects.area_id = targetAreaId`
- `projects.sort_order = targetArea 最大值 + 1`
- `projects.updated_at = now`
- `projects.is_dirty = true`

移动到“独立项目”时写 `area_id = NULL`。

## 5. 数据模型与 DAO

### 5.1 已有表字段

当前 `client/lib/database/tables.dart` 已具备：

- `Areas(id, serverId, name, iconName, sortOrder, isDirty, createdAt, updatedAt)`
- `Projects(areaId, iconName, notes, whenType, deadline, status, completedAt, sortOrder)`
- `Headings(projectId, title, sortOrder, archivedAt)`
- `Tasks(projectId, headingId, sortOrder)`

因此 M2 不需要再做 schema migration，主要补 DAO 和 UI。

### 5.2 需要补齐的 DAO

当前已有：

- `watchAreas()`
- `watchProjectsByArea(String? areaId)`
- `watchProjectProgress(String projectId)`
- `watchHeadings(String projectId)`
- `watchTasksByHeading(String headingId)`
- `insertArea(...)`
- `insertHeading(...)`
- `reorderAreas(...)`
- `reorderHeadings(...)`

建议补齐：

| 方法 | 用途 |
|---|---|
| `updateArea(id, name, iconName)` | 区域编辑 |
| `deleteArea(id)` | 解除项目归属后删除区域 |
| `createProject({name, areaId, color, iconName, deadline, notes})` | 替代当前仅 name/color 的创建 |
| `updateProjectDetails(...)` | 项目详情编辑 |
| `moveProjectToArea(projectId, areaId)` | 项目跨区域移动 |
| `reorderProjects(areaId, orderedIds)` | 区域内项目排序 |
| `completeProject(projectId, taskPolicy)` | 完成项目及未完成任务处理 |
| `watchAreaSummary(areaId)` | 区域统计：项目数、任务数、完成数 |
| `watchProjectSections(projectId)` | 一次返回 Heading + 对应任务，减少 UI 多层 StreamBuilder |

## 6. SelectionStore 与路由

`SelectionStore` 已有 `SidebarView.area` 与 `SidebarView.project`，可直接承接动态 Sidebar。

交互规则：

- 点击 Area：`selectView(SidebarView.area, entityId: area.id)`
- 点击 Project：`selectView(SidebarView.project, entityId: project.id)`
- 切换 Area/Project 时清空 `selectedTaskId`
- 桌面宽度点击任务行：更新 `selectedTaskId`，DetailPane 显示任务详情
- 移动/平板点击任务行：打开全屏或 sheet，不写 `selectedTaskId`

`ShellContent` 当前对 `SidebarView.area` 仍使用 Inbox 兜底；M2 需要改为 `AreaPage(areaId)`。

## 7. 本期落地范围

### M2-A：基础可用

- Sidebar 展示 Areas 和 Projects。
- 新建/编辑/删除 Area。
- 新建/编辑 Project 时可选择 Area。
- Area 视图展示项目列表。
- Project 视图按 Heading/未分节任务展示。
- 项目进度环和未完成数可见。

### M2-B：组织效率

- 项目拖入 Area。
- Area 内项目拖拽排序。
- Project 内任务拖拽排序。
- Heading 新建、重命名、归档、排序。
- Quick Find 支持跳转 Area/Project。

### M2-C：状态闭环

- 完成/取消/删除项目。
- 项目归档视图或 Logbook 中的项目维度。
- Area/Project 统计进入 AI 周报。

## 8. 验收标准

基础功能：

- 用户可以创建 Area，并在 Sidebar 看到该 Area。
- 用户可以在某个 Area 下创建 Project。
- 用户可以把已有 Project 移动到 Area 或移出 Area。
- 点击 Area 能看到该 Area 下所有项目。
- 点击 Project 能看到该项目下所有任务，并可继续添加任务。
- 删除 Area 不会删除项目和任务。

数据正确性：

- `projects.area_id` 正确反映项目归属。
- `tasks.project_id` 不因移动项目到 Area 而变化。
- 项目完成后 `projects.status` 和 `completed_at` 正确写入。
- 任务仍按既有 Today / Calendar / Someday / Logbook 规则出现，不因 Area 改变 When 语义。

桌面体验：

- Sidebar 选中态在 Area/Project 间正确切换。
- 桌面点击任务行能打开右侧 DetailPane。
- 折叠 Area 后重启应用仍保持本地折叠状态。

## 9. 边界与暂不做

- Area 暂不直接承载任务；如果用户想放单个任务，应创建 Project 或放 Inbox。
- Area 暂不设置 deadline / notes / status。
- Area 不参与协作权限；协作仍以 Project 为边界。
- M2 不做嵌套 Area。
- M2 不做复杂项目模板；可在 M3 评估“从项目复制为模板”。

## 10. 与 Things 的差异

Flowlog 保持 Things 的核心组织语义，但做两点本地化：

- Project 仍兼容当前“清单”习惯，短期 UI 文案可从“清单”逐步迁移到“项目”。
- Area 不直接承载任务，避免 Inbox/Anytime/Area 三套任务归属语义混乱。
