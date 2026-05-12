# 产品逻辑与功能设计 (Product Logic)

> 目标：对齐 Things 3/4 的产品语言（Area > Project > Heading > Task > Checklist + When/Deadline/Reminder 三轴），
> 在现有本地优先架构上补齐子任务、Heading、Checklist、Quick Entry、拖拽、多选、Mac 快捷键等体验。
> 多端化（iOS / iPadOS / Android / macOS）落地步骤详见 `flowlog_design/refactor/`。

## 1. 产品定位
*   **离线优先**：所有操作直接写本地，后台异步同步。
*   **设备配对**：无账号多端同步，以设备配对为核心流程。
*   **三轴时间**：When（计划做的日期/语义）/ Deadline（必须前完成）/ Reminder（提醒时刻）三者解耦。
*   **高频高效**：全局快捷键 + Quick Entry 悬浮卡 + 拖拽 + 多选，降低操作成本。
*   **多端原生体验**：同一份 Flutter 代码，按断点分发 Mobile / Tablet / Desktop 三档布局。

## 2. 信息架构 (Navigation)

视图体系参考 Things：固定 6 个核心视图 + 动态 Areas/Projects + 工具入口。

### 2.1 固定视图（侧边栏 / 底部 Tab 共用）

| 视图 | 含义 | 数据规则 |
|---|---|---|
| **Inbox** | 未分类、未安排 | `status=Todo` 且 `project_id IS NULL` 且 `when_type=0` |
| **Today** | 今天要做的 | `when_type IN (1, 2)` 或 (`when_type=4` 且 `due_date=today`) 或 逾期未完成 |
| **Upcoming** | 已安排到未来 | `when_type=4` 且 `due_date > today`，按日期分组 |
| **Anytime** | 随时可做 | `when_type IN (0, 4)` 且 `status=Todo`（含项目内任务）|
| **Someday** | 模糊"有空再说" | `when_type=3` 且 `status=Todo` |
| **Logbook** | 已完成历史 | `status=Done` 且 `in_logbook=true`，按 `completed_at DESC` |

> Today 内进一步分两段：**This Morning**（默认）/ **This Evening**（`evening=true` 或 `when_type=2`）。
> 逾期任务（`due_date < today` 且未完成）置顶并加红色徽标，不再单独折叠组。

### 2.2 动态视图

* **Areas**：项目分组（Things 风），可折叠。Area 不直接承载任务，只作为 Project 的容器。
* **Projects**：清单，带圆形进度环。可归属 Area 或独立。
* **Tags**：标签筛选入口（次级，桌面侧边栏可隐藏）。

### 2.3 工具入口

* **Search / Quick Find** (`Cmd+K`)：命令面板，统一搜索任务、项目、设置。
* **Trash**：软删除任务恢复 / 永久删除。
* **Settings**：主题、语言、通知、AI、快捷键、设备配对。

### 2.4 三档断点布局（详见 `refactor/M1_04`）

| 宽度 | 形态 |
|---|---|
| `< 600`     | 底部 NavigationBar 5 项：Today / Upcoming / Anytime / Inbox / Projects；其余视图通过 Projects 页或菜单进入 |
| `600–1000`  | 双栏：左侧完整 Sidebar，右侧内容；详情走 modal sheet |
| `≥ 1000`    | 三栏：Sidebar + List + 常驻 DetailPane，分隔条可拖动 |

## 3. 核心对象与字段 (Data Model)

> 完整 schema 与字段语义见 `flowlog_design/03_Client_Design.md` §3。本节仅列产品视角的关键字段。

### 3.1 Task
*   `id` (UUID), `title`, `notes` (Markdown)
*   `status` (Todo/Done/Deleted), `priority`
*   **When 轴**：`when_type` (none / today / evening / someday / scheduled), `due_date`
*   **Deadline 轴**：`deadline`
*   **Reminder 轴**：`reminder_at`
*   `is_all_day`, `evening`
*   `project_id`, `heading_id`, `sort_order`
*   `repeat_rule`, `repeat_mode`, `repeat_until`
*   `parent_id` (子任务)
*   `in_logbook` (完成后是否进 Logbook)
*   `created_at`, `updated_at`, `completed_at`

### 3.2 Subtask
*   与 Task 同表，通过 `parent_id` 关联。
*   是完整任务对象（有自己的 due / priority / tags），出现在 Today / Anytime 等视图。
*   父任务详情显示完成进度（x/y）。

### 3.3 Checklist Item（任务内勾选项）
*   独立表 `checklists`，仅含 `title` + `is_checked` + `sort_order`。
*   仅在父任务详情中显示，**不进入任何视图**。
*   与 Subtask 的核心区别：Checklist 是"任务内的勾选清单"，Subtask 是"独立子任务"。

### 3.4 Project / List
*   `name`, `color`, `icon_name`, `notes`
*   `area_id`（归属 Area）
*   `when_type`, `deadline`（项目本身可设 When/Deadline）
*   `status` (Active / Completed / Cancelled / Deleted), `completed_at`
*   `sort_order`

### 3.5 Heading（项目内分节）
*   `project_id`, `title`, `sort_order`, `archived_at`
*   不是任务，是项目内的章节标题，用于分隔大量任务。

### 3.6 Area（项目分组）
*   `name`, `icon_name`, `sort_order`
*   不直接承载任务，只作为 Project 的逻辑分组（如"工作 / 生活 / 学习"）。

### 3.7 Tag
*   `name`, `color`, `sort_order`

## 4. 视图规则 (View Rules)

| 视图 | 过滤条件 | 排序 |
|---|---|---|
| **Inbox** | `status=Todo` 且 `project_id IS NULL` 且 `when_type=0` | `sort_order` |
| **Today (This Morning)** | `when_type=1` 且 `evening=false`，或 `when_type=4` 且 `due_date=today`，或 逾期未完成 | `sort_order` |
| **Today (This Evening)** | `when_type=2` 或 `evening=true` | `sort_order` |
| **Upcoming** | `when_type=4` 且 `due_date > today` | 按 `due_date` 分日期分组 |
| **Anytime** | `when_type IN (0, 4)` 且 `status=Todo` | 项目分组 + `sort_order` |
| **Someday** | `when_type=3` 且 `status=Todo` | `sort_order` |
| **Logbook** | `status=Done` 且 `in_logbook=true` | `completed_at DESC`，最近 90 天 |
| **Project** | `project_id=?`，按 Heading 分节 | `heading_id`, `sort_order` |
| **Area** | 列出 `area_id=?` 的所有 Project，每个 Project 显示进度 | `sort_order` |
| **Tag** | `task_tags` 关联过滤 | `sort_order` |
| **Trash** | `status=Deleted` | `updated_at DESC` |

> Deadline（截止日）独立于视图过滤——任何视图中只要任务有 deadline 就显示红色徽标。
> 临近 deadline 的任务（≤ 3 天）在视图内自动置顶。

## 5. 提醒与通知 (Notifications)
*   **即将到期提醒**：每天 17:00 固定提醒一次（汇总未来 24 小时内任务），并在任务到期前 30 分钟提醒（单任务）。
*   **到期时提醒**：仅对未完成任务，在到期时间触发提醒；全天任务默认按 17:00 触发。
*   **日报提醒**：自定义时间触发，文案格式：`今日待办 {due}，已完成 {done}，逾期 {overdue}`。
*   **周报提醒**：自定义星期+时间触发，文案格式：`本周已完成 {done}，新增 {created}，到期 {due}，未完成 {open}`。
*   **设置入口**：设置 > 提醒和通知，可开关各类提醒与提醒声音。

## 6. 核心交互流程

### 6.1 创建任务
*   每个视图顶部行内 Quick Add（M2 仍保留）+ 全局 Quick Entry 悬浮卡（M3）。
*   视图上下文决定默认值：
    *   **Today**：`when_type=1`，`due_date=今天`
    *   **This Evening**（Today 内的子分组）：`when_type=2`
    *   **Inbox**：`when_type=0`，`project_id=null`
    *   **Upcoming 某天**：`when_type=4`，`due_date=该日期`
    *   **Anytime**：`when_type=0`
    *   **Someday**：`when_type=3`
    *   **Project / Heading 内**：继承 `project_id` / `heading_id`

### 6.2 任务详情
*   字段分区：**When picker** / **Deadline picker** / **Reminder picker** / Project + Heading / Tags / Notes (Markdown) / Checklist / Subtask / Repeat。
*   When picker 选项：Today / This Evening / Tomorrow / This Weekend / Specific Date / Someday。
*   Deadline picker 与 When 独立。
*   Reminder picker 与 due_date 独立。
*   重复任务编辑弹窗：本次 / 本次及之后 / 全部（详见 03 文档 §5.3）。

### 6.3 子任务（Subtask）
*   在任务详情页添加子任务，按"+ Add to-do"按钮。
*   子任务是完整任务，可独立设 When / Deadline / Tags。
*   子任务可拖拽排序。
*   父任务显示完成进度（x/y）。

### 6.4 勾选项（Checklist）
*   在任务详情页添加 Checklist Item，按"+ Add checklist"按钮。
*   只有标题 + 勾选状态，不进入任何视图。
*   适合"打包行李 → 充电器 / 牙刷 / 护照"这种轻量步骤拆解。

### 6.5 Heading（项目内分节）
*   在 Project 详情页可插入 Heading（"+ Add heading"）。
*   Heading 下的任务渲染为分节列表。
*   Heading 可归档（archived_at），归档后该节任务收起到底部。

### 6.6 Quick Entry（全局速记，M3）
*   Mac/Windows 全局热键召出悬浮卡片。
*   单输入框 + Tab 切换：When / Deadline / Tags / Project / Notes。
*   `Cmd+Enter` 保存，`Esc` 取消。
*   不打断当前应用焦点。

### 6.7 拖动分类 (Drag & Drop)
*   **拖到 Today**：`when_type=1`, `due_date=today`
*   **拖到 This Evening**：`when_type=2`, `evening=true`
*   **拖到 Upcoming 某天**：`when_type=4`, `due_date=该日期`
*   **拖到 Anytime**：`when_type=0`
*   **拖到 Someday**：`when_type=3`
*   **拖到 Inbox**：清空 `project_id` 与 `when_type=0`
*   **拖到清单 / Heading**：修改 `project_id` / `heading_id`
*   **拖到标签**：新增关联标签
*   **同列表内拖拽**：更新 `sort_order`

### 6.8 多选与批量操作（M3）
*   桌面：Shift / Cmd 点击进入多选；移动：长按进入多选。
*   批量动作：移到项目 / 设 When / 设 Deadline / 加标签 / 删除 / 复制。
*   Mac 工具栏 / 移动顶栏切换为多选操作条。

### 6.9 排序模式
*   支持：手动 / 创建时间 / 截止时间 / 优先级。
*   默认手动（`sort_order`），切换其他模式时不修改 `sort_order`，仅改变本次显示顺序。

### 6.10 AI 快速添加（文本/图片）
*   文本模式：本地或云端解析自然语言，提取标题、`when_type` + `due_date`、`reminder_at`、标签、备注。
*   图片模式：仅云端解析，从截图/照片中抽取可执行任务，允许输入提示词补充上下文。
*   生成结果先预览，再确认写入。

### 6.11 智能助手（任务知识库）
*   读取本地任务作为上下文进行问答与总结，仅用于查询与建议，不直接写入任务。
*   提供周报/月报/年报快捷生成入口。

## 7. 快捷键

### 7.1 全局（系统级，需注册）
*   `Ctrl+Space`（macOS：可改为 `Cmd+Shift+Space`）：召出 Quick Entry 悬浮卡

### 7.2 应用内（macOS / Windows / Linux）
*   `Cmd+N` / `Ctrl+N`：当前视图新建任务
*   `Cmd+Shift+N`：新建任务到 Inbox
*   `Cmd+Opt+N`：新建任务到 Today
*   `Cmd+F`：当前视图搜索
*   `Cmd+K`：Quick Find（命令面板，搜任务/项目/设置）
*   `Cmd+1/2/3/4/5/6`：切换 Inbox / Today / Upcoming / Anytime / Someday / Logbook
*   `Cmd+Shift+T`：Today
*   `Cmd+Shift+I`：Inbox
*   `Cmd+T`：在选中任务上打开 When picker
*   `Cmd+Shift+D`：在选中任务上打开 Deadline picker
*   `Cmd+E`：归档当前选中任务（标记 Done）
*   `Cmd+Backspace`：删除（移到 Trash）
*   `Esc`：关闭弹窗 / 取消多选 / 退出详情

### 7.3 移动端
*   外接键盘时复用桌面快捷键集合（iPad / Android 平板）。

## 8. 多端同步（设备配对）
*   主设备生成短效配对码。
*   新设备扫码/输入配对码加入同一 account。
*   首次配对走全量同步，后续走增量。

## 9. AI 报告（周报/月报/年报）
*   基于任务完成、专注统计、清单/标签分布生成摘要。
*   支持定时生成与按需生成。
*   报告可缓存与导出。

## 10. 多端形态与差异

| 平台 | 主要交互 | 平台特有 |
|---|---|---|
| **iPhone / Android 手机** | 底部 Tab + 全屏详情 + 长按多选 + 滑动手势（左滑删除 / 右滑完成） | 通知运行时权限、Magic Plus 拖拽插入位置 |
| **iPad / Android 平板** | 双栏 Sidebar+Content；横屏自动三栏；外接键盘走桌面快捷键 | iPad 分屏 / Slide Over 兼容 |
| **macOS** | 三栏 Sidebar+List+Detail；全局热键；菜单栏；可拖动分隔条 | 隐藏 titlebar、Carbon HotKey、Dock 角标 |
| **Windows / Linux**（M4 评估） | 三栏 + 系统托盘 | 亚克力背景（可选）、Windows 11 圆角 |
| **Web**（不在路线图内） | 仅作为分享 / 查看页（如有需要后置） | — |

## 11. 提醒策略与平台差异

* **macOS**：通知中心 + 菜单栏角标，全局热键直达 Quick Entry。
* **iOS**：首次创建带 reminder 的任务时请求通知权限（不在启动时请求）。锁屏 / 通知中心展示。
* **Android 13+**：首次创建带 reminder 的任务时请求 `POST_NOTIFICATIONS`；精确闹钟需引导用户去系统设置开启 `SCHEDULE_EXACT_ALARM`。
* **跨端一致**：所有 reminder 在本地调度（`flutter_local_notifications`），同步到云端后由其他设备各自重新调度。

## 12. 设计原则

1. **离线可用 > 云端一致**：所有功能在断网下仍完整工作。
2. **三轴解耦**：When（做的时间）/ Deadline（截止时间）/ Reminder（提醒时间）三件事独立，避免 TickTick 风格的"due 一刀切"导致的语义混淆。
3. **Subtask vs Checklist 边界清晰**：前者是任务，后者是任务内的勾选清单，不混用。
4. **平台对齐而非平台一致**：每端遵循自己的设计语言（iOS 走 SF / Material You 走系统色），但功能完全一致。
5. **AI 不作主**：AI 仅在 Quick Add 与报告中提供建议，所有写入需用户确认。
