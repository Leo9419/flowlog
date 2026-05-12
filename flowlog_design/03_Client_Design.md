# 客户端详细设计 (Client Design)

> 本文档为客户端长期目标设计。当前与 M1 重构（对齐 Things + 多端化）相关的具体落地步骤见
> `flowlog_design/refactor/00_Overview.md`。本文档已按 M1 目标更新数据模型、视图体系与自适应 Shell。

## 1. 核心架构模式：离线优先 (Local-First)

与传统 App 不同，FlowLog 的操作**不需要等待网络回调**。
UI 只与本地数据库交互，后台 Sync Engine 负责将本地变更同步到云端。

### 1.1 架构分层
*   **UI Layer (Flutter Widgets)**: 响应式 UI，监听本地数据库流 (Stream)。
*   **Adaptive Shell Layer**: 顶层壳按屏幕宽度分发到 Mobile / Tablet / Desktop 三档布局，详见 §6。
*   **State Management (Provider + ChangeNotifier)**: 处理业务逻辑，`SelectionStore` 管理"当前侧边栏视图 / 当前选中任务"。
*   **Repository Layer**: 决定数据来源，但 99% 情况直接读写 Local DB。
*   **Local Data Source (SQLite via Drift)**: 单一事实来源 (Source of Truth)。
*   **Remote Data Source (API)**: 仅由 Sync Engine 调用。
*   **Theme & Tokens (`lib/theme/`)**: 集中管理 Spacing / Radii / Elevation / Typography / ColorScheme。Android 12+ 通过 `dynamic_color` 接入 Material You。

## 2. 同步引擎 (Sync Engine) 设计

这是客户端最复杂的组件，负责解决“多端冲突”和“断网重连”。

### 2.1 变更队列 (Mutation Queue)
当用户创建任务时：
1.  生成临时的 UUID。
2.  写入 SQLite `tasks` 表，标记 `sync_status = dirty`。
3.  写入 SQLite `mutations` 表 (记录操作日志: `CREATE_TASK` / `UPDATE_TASK` / `CREATE_PROJECT` / `TAG_UPDATE` 等).
4.  UI 立即更新。

### 2.2 同步流程
后台 Worker 定期或网络恢复时触发：
1.  **Push**: 读取 `mutations` 表，打包成 Protobuf 发送给 Server。
    *   成功：删除 mutations 记录，更新 tasks `sync_status = synced`。
    *   失败：保留记录，指数退避重试。
2.  **Pull**: 发送 `SyncRequest(last_checkpoint)` 给 Server。
    *   收到 `SyncResponse`。
    *   **合并策略**:
    *   Server 变更覆盖本地变更 (Last Write Wins 简化版)。
    *   或者：如果本地也有修改，保留本地修改并标记为冲突，让用户解决（高级）。

### 2.3 无账号多端同步（设备配对）
*   **设备注册**: 首次安装生成 `device_id`，向服务端注册获取 `device_token`。
*   **配对流程**: 主设备生成 `pair_code/QR`，新设备输入/扫码加入同一 `account_id`。
*   **连接流程**: WebSocket 连接时发送 `DeviceHandshake` (device_token + device_id + account_id)。
*   **首次同步**: 新设备配对后走全量快照，写入本地 DB 并初始化 `last_checkpoint`。
*   **增量同步**: 后续仅传输变更 (mutations)，并用 `server_checkpoint` 推进本地游标。
*   **离线模式**: 未配对也可本地使用；配对时需提供“本地数据合并/覆盖”策略选择。
*   **Token 刷新**: device_token 过期前自动 refresh；刷新失败则暂停同步并提示重新配对。
*   **设备管理**: 提供设备列表与“移除设备/退出全部设备”入口。

## 3. 本地数据库 Schema (SQLite via Drift)

数据模型对齐 Things：**Area > Project > Heading > Task > Checklist** 五级结构 + 双轴时间（When / Deadline）+
独立提醒 (Reminder)。所有表都包含同步辅助字段 (`serverId` / `isDirty`)。

> 字段命名按 Drift 实际生成的 Dart camelCase 表示；SQL 列名为 snake_case。
> 详细的迁移脚本与字段语义见 `flowlog_design/refactor/M1_01_Data_Model.md`。

```sql
-- ============ 业务实体 ============

-- 区域（Things 的 Area）
CREATE TABLE areas (
    id TEXT PRIMARY KEY,
    server_id TEXT,
    name TEXT NOT NULL,
    icon_name TEXT,
    sort_order INTEGER DEFAULT 0,
    is_dirty INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 清单 / 项目
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    server_id TEXT,
    name TEXT NOT NULL,
    color TEXT,
    icon_name TEXT,
    notes TEXT DEFAULT '',
    area_id TEXT REFERENCES areas(id),
    when_type INTEGER DEFAULT 0,         -- 0=none, 1=today, 2=evening, 3=someday, 4=scheduled
    deadline INTEGER,
    status INTEGER DEFAULT 0,            -- 0=Active, 1=Completed, 2=Cancelled, 3=Deleted
    completed_at INTEGER,
    sort_order INTEGER DEFAULT 0,
    is_dirty INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 项目内分节（Things 的 Heading）
CREATE TABLE headings (
    id TEXT PRIMARY KEY,
    server_id TEXT,
    project_id TEXT NOT NULL REFERENCES projects(id),
    title TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    archived_at INTEGER,
    is_dirty INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 任务
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    server_id TEXT,
    title TEXT NOT NULL,
    notes TEXT DEFAULT '',               -- Markdown 备注（M1 引入，逐步替代 content）
    content TEXT DEFAULT '',             -- 兼容旧字段，下个 schema version 删除
    priority INTEGER DEFAULT 0,
    -- When / Deadline / Reminder 三轴
    when_type INTEGER DEFAULT 0,         -- 0=none, 1=today, 2=evening, 3=someday, 4=scheduled
    due_date INTEGER,                    -- 计划日期（与 when_type=4 配合）
    deadline INTEGER,                    -- 必须前完成（与 when_type 解耦）
    reminder_at INTEGER,                 -- 独立提醒时刻
    end_date INTEGER,
    is_all_day INTEGER DEFAULT 1,
    evening INTEGER DEFAULT 0,           -- Today 视图下"This Evening"分组冗余字段
    -- 重复
    repeat_rule TEXT,                    -- RRULE
    repeat_mode TEXT,                    -- 'BY_DUE' | 'BY_COMPLETE'
    repeat_until INTEGER,
    -- 关系
    parent_id TEXT,                      -- 子任务（仍保留，与 Checklist 不同）
    project_id TEXT REFERENCES projects(id),
    heading_id TEXT REFERENCES headings(id),
    -- 状态
    status INTEGER DEFAULT 0,            -- 0=Todo, 1=Done, 2=Deleted
    completed_at INTEGER,
    in_logbook INTEGER DEFAULT 1,        -- 完成后是否进 Logbook
    -- 排序
    sort_order INTEGER DEFAULT 0,
    -- 同步
    is_dirty INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 任务内勾选项（Things 的 Checklist，区别于 Subtask）
CREATE TABLE checklists (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL REFERENCES tasks(id),
    title TEXT NOT NULL,
    is_checked INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    is_dirty INTEGER DEFAULT 1,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 标签
CREATE TABLE tags (
    id TEXT PRIMARY KEY,
    server_id TEXT,
    name TEXT NOT NULL,
    color TEXT,
    sort_order INTEGER DEFAULT 0
);

-- 任务-标签关联
CREATE TABLE task_tags (
    task_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    PRIMARY KEY (task_id, tag_id)
);

-- 重复任务例外/实例覆盖
CREATE TABLE recurrence_exceptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    instance_date INTEGER NOT NULL,
    action TEXT,                          -- 'SKIP' | 'OVERRIDE'
    override_payload TEXT
);

-- ============ 同步辅助 ============

-- 同步状态
CREATE TABLE sync_state (
    account_id TEXT,
    device_id TEXT,
    last_checkpoint INTEGER,
    last_full_sync_at INTEGER,
    last_sync_at INTEGER,
    PRIMARY KEY (account_id, device_id)
);

-- 变更日志（Mutation Queue）
CREATE TABLE mutations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_type TEXT,                     -- 'CREATE' | 'UPDATE' | 'DELETE'
    entity_table TEXT,                    -- 'tasks' | 'projects' | 'areas' | ...
    entity_id TEXT,
    payload TEXT,                         -- JSON 格式的变更内容
    created_at INTEGER
);
```

### 3.1 子任务（Subtask）vs 勾选项（Checklist）

| 维度 | Subtask | Checklist |
|---|---|---|
| 表 | `tasks(parent_id)` | `checklists(task_id)` |
| 是否独立任务 | 是。有自己的优先级、due_date、tags | 否。仅标题 + 勾选 |
| 是否进入视图（Today / Anytime 等） | 会 | 不会，只在父任务详情中显示 |
| 同步粒度 | 独立 mutation | 跟随父任务，整体打包同步 |

### 3.2 When / Deadline / Reminder 三轴

| 字段 | 含义 | 影响视图 |
|---|---|---|
| `when_type=1 today` | 用户决定今天做 | 出现在 Today |
| `when_type=2 evening` | 今晚做 | Today 内 "This Evening" 分组 |
| `when_type=3 someday` | 模糊"有空再说" | Someday 视图 |
| `when_type=4 scheduled + due_date` | 安排到具体日期 | Upcoming（未来）/ Today（当天） |
| `when_type=0 none` | 未安排 | Anytime / Inbox |
| `deadline` | 截止日（独立于 when_type） | 任意视图均显示红色截止徽标 |
| `reminder_at` | 独立提醒时刻 | 触发 Notification |

> 例：一个任务可以是 "Anytime + 周五 deadline + 周三晚 21:00 提醒"。
> 这是 Things 与 TickTick 等工具最显著的差异——把"做的时间 / 截止时间 / 提醒时间"三件事彻底解耦。

## 4. 关键交互细节

*   **Area / Project / Heading 三级组织**: 侧边栏 Areas 可折叠，内含 Projects（带圆形进度环）；项目页内可插入 Heading 分节。Heading 不是任务，是项目内的章节标题。
*   **When picker**: 任务详情中独立的 When 选择器，支持 Today / This Evening / Tomorrow / This Weekend / Someday / 自定义日期。写入 `when_type` 与 `due_date` 同事务。
*   **Deadline picker**: 与 When 解耦的截止日，UI 上以红色圆角徽标展示（"⚑ Fri" 风格）。
*   **Reminder picker**: 独立提醒时刻，写入后由 `NotificationService` 调度本地通知。
*   **Checklist**: 任务详情中的轻量勾选列表，与 Subtask 区分（详见 §3.1）。
*   **标签**: 输入框解析 `#tag` 自动关联，支持标签筛选、颜色、常用标签推荐与重命名合并。
*   **重复任务**: 支持 RRULE、重复模式 (按到期/完成后)、结束条件；完成实例时写入 `recurrence_exceptions` 或更新下一次 `due_date`。
*   **拖拽排序**: 对清单/分组/Heading 内任务使用 `sort_order` 排序。
    *   M1 用整数 sort_order（步长 1，重排整段）。
    *   M3 评估升级到 LexoRank 字符串避免频繁全列重排，必要时做批量压缩。
*   **多选与批量操作**（M3）: 桌面端 Shift/Cmd 多选；移动端长按进入多选模式。批量操作：移到项目 / 设 When / 设 Deadline / 加标签 / 删除。
*   **智能识别 (NLP)**: 客户端集成 NLP 库 (如 `Duckling` 的 WASM 版或简易正则库)，在用户输入时实时高亮时间词汇 (如 "明天下午3点")，并在提交时自动转换为 `due_date` + `when_type=4`。

## 5. UI/UX 流程

### 5.1 清单管理
*   **入口**: 左侧栏 “LISTS” 区域 + 管理页。
*   **创建清单**: 点击 “+” -> 弹窗填写名称/颜色 -> 生成 `projects` 记录并插入侧边栏。
*   **编辑清单**: 右键/长按清单 -> Rename / Change Color / Archive / Delete (软删除)。
*   **排序**: 拖拽清单排序，更新 `sort_order`（LexoRank）。
*   **归档**: 归档清单默认隐藏，管理页可查看并恢复。

### 5.2 标签管理
*   **快速关联**: 输入框解析 `#tag` 自动创建/关联，支持补全与最近使用标签。
*   **任务详情**: 标签以 Chip 形式展示，点击进入选择器，可新建、移除、改色。
*   **标签列表**: 独立管理页，支持重命名、合并（合并后更新 `task_tags`）、颜色管理。
*   **筛选**: 侧边栏 Tags 入口，支持单标签或多标签组合筛选（AND/OR 可配置）。

### 5.3 重复任务编辑（本次 / 本次及之后 / 全部）
*   **编辑触发**: 修改重复任务的标题、时间、清单、标签、优先级等任一字段时弹出选择框。
*   **仅本次**:
    *   创建 `recurrence_exceptions` 记录（`action=OVERRIDE`），保存修改字段。
    *   原 RRULE 不变，该实例仅在本地渲染为覆盖内容。
*   **本次及之后**:
    *   结束旧系列：设置原任务 `repeat_until` 为实例前一天。
    *   新建新系列：复制任务并从本次日期开始应用新规则/新字段。
*   **全部**:
    *   直接更新原任务字段，所有实例统一生效。
*   **完成/删除**:
    *   完成本次：根据 `repeat_mode` 推进下次 `due_date`；必要时记录 `SKIP`/`OVERRIDE`。
    *   删除本次：写 `recurrence_exceptions`（`action=SKIP`）。
    *   删除本次及之后 / 全部：同编辑策略处理系列结束或软删除。

### 5.4 设备配对与管理
*   **入口**: 个人页显示“设备配对”入口，未配对状态支持继续本地使用。
*   **配对方式**: 显示配对码/二维码，或输入配对码加入。
*   **设备管理**: 设备列表支持“移除设备/退出全部设备”。
*   **合并策略**: 首次配对提示选择“保留本地/以云端为准/合并”。

## 6. 自适应 Shell（Adaptive Shell）

> 详细设计与文件结构见 `flowlog_design/refactor/M1_04_Adaptive_Shell.md`。

### 6.1 三档断点

| 断点 | 布局 | 典型设备 |
|---|---|---|
| `< 600`     | **Mobile**：单栏 + 底部 NavigationBar 5 项 + 详情全屏 push | iPhone / Android 手机 |
| `600–1000`  | **Tablet**：双栏（Sidebar + Content） + 详情 modal sheet | iPad 竖屏 / Android 平板 |
| `≥ 1000`    | **Desktop**：三栏（Sidebar + List + DetailPane）+ 可拖动分隔条 | macOS / iPad 横屏 / Windows |

### 6.2 关键组件

* `AdaptiveShell`：顶层 `LayoutBuilder`，按宽度路由到 `MobileShell` / `TabletShell` / `DesktopShell`。
* `Sidebar`：tablet/desktop 共用。Things 风格 6 项（Inbox / Today / Upcoming / Anytime / Someday / Logbook）+ 动态 Areas/Projects + 底部 Trash/Settings。
* `DetailPane`：仅 desktop 常驻，监听 `SelectionStore.selectedTaskId`。
* `SelectionStore` (`lib/state/selection_store.dart`)：全局 `ChangeNotifier`，承载 `(view, entityId, selectedTaskId)`。所有视图与详情面板通过它协调。

### 6.3 平台差异收敛点

| 能力 | 抽象位置 | 平台实现 |
|---|---|---|
| 全局热键 | `GlobalHotkeyService` 接口 | macOS 用 Carbon；iOS / Android 走 noop |
| 通知 | `NotificationService`（已有） | iOS 延后请求；Android 13+ 运行时权限 |
| 窗口装饰 | M4：`lib/platform/window_chrome.dart` | macOS hidden titlebar；其他默认 |
| 主题色 | `dynamic_color` + `appLightTheme/appDarkTheme` | Android 12+ Material You；其他回退品牌色 |
