# 功能模块细分 (Feature Breakdown)

> 产品语言对齐 Things：Area > Project > Heading > Task > Checklist + When/Deadline/Reminder 三轴。
> 详细设计见 `03_Client_Design.md` / `05_Product_Logic.md`，落地路线图见 `refactor/00_Overview.md`。

## 1. 视图体系 (Views)

### 1.1 固定 6 视图

| 视图 | 含义 | 数据规则 |
|---|---|---|
| **Inbox** | 未分类、未安排 | `status=Todo` 且 `project_id IS NULL` 且 `when_type=0` |
| **Today** | 今天要做（含 This Evening 子分组 + 逾期置顶） | `when_type IN (1,2)` 或 `due_date=today` 或 逾期 |
| **Upcoming** | 已安排到未来，按日期分组 | `when_type=4` 且 `due_date > today` |
| **Anytime** | 随时可做（含项目内任务） | `when_type IN (0,4)` 且 `status=Todo` |
| **Someday** | 模糊"有空再说" | `when_type=3` 且 `status=Todo` |
| **Logbook** | 已完成历史 | `status=Done` 且 `in_logbook=true` |

### 1.2 动态视图
* **Areas**：项目分组容器，可折叠
* **Projects**：清单，带圆形进度环
* **Tags**：标签筛选

### 1.3 工具入口
* **Search / Quick Find** (`Cmd+K`)：命令面板，统一搜索任务/项目/设置
* **Trash**：软删除恢复
* **Settings**

### 1.4 自适应布局
* `< 600`：MobileShell（底部 Tab + 全屏详情）
* `600–1000`：TabletShell（双栏 Sidebar+Content）
* `≥ 1000`：DesktopShell（三栏 + 常驻 DetailPane）

## 2. 任务管理 (Core Task)

### 2.1 快速添加 (Quick Add)
*   **功能**: 视图顶部行内输入框，支持文本 + 语音 + 图片。
*   **上下文默认值**：当前视图决定 `when_type` / `project_id` 等默认（详见 `05_Product_Logic.md` §6.1）。
*   **技术点**:
    *   **NLP 解析**: 识别 "Next Friday", "Every day", "Priority High" 等关键词，写入 `when_type=4 + due_date`。
    *   **Smart Parsing**: 提取标签 (#work) 和清单 (^inbox)。
    *   **AI 模式**: 文本走本地或云端 LLM；图片走云端识别。结果先预览再写入。

### 2.2 Quick Entry（全局速记，M3）
*   **功能**: 全局热键召出悬浮卡，单输入框 + Tab 切换 When / Deadline / Tags / Project / Notes。
*   **技术点**:
    *   macOS / Windows / Linux：注册系统级全局热键（默认 `Ctrl+Space` / `Cmd+Shift+Space`）。
    *   不打断当前应用焦点，`Cmd+Enter` 保存，`Esc` 关闭。
    *   iOS / Android 由 Magic Plus 与 Share Extension 替代。

### 2.3 三轴时间 (When / Deadline / Reminder)
*   **When picker**: Today / This Evening / Tomorrow / This Weekend / Specific Date / Someday；写入 `when_type` + `due_date` 同事务。
*   **Deadline picker**: 与 When 解耦，UI 显示红色 "⚑ Fri" 徽标。
*   **Reminder picker**: 与 due_date 解耦，写入 `reminder_at` 后由 `NotificationService` 调度本地通知。
*   **解耦的意义**: 一个任务可以是 "Anytime + 周五 deadline + 周三晚 21:00 提醒"。

### 2.4 Area / Project / Heading 三级组织
*   **Area**: 项目分组容器（如"工作 / 生活 / 学习"），不直接承载任务。
*   **Project**: 清单，归属 Area 或独立。带圆形进度环，可设 `when_type` / `deadline`。
*   **Heading**: 项目内分节标题（"+ Add heading"），不是任务，用于分隔大量任务。可归档。

### 2.5 Subtask vs Checklist
| 维度 | Subtask | Checklist |
|---|---|---|
| 表 | `tasks(parent_id)` | `checklists(task_id)` |
| 是否独立任务 | 是。有自己的优先级 / due / tags | 否。仅标题 + 勾选 |
| 是否进入视图 | 进入 Today / Anytime 等 | 仅在父任务详情中显示 |
| 同步粒度 | 独立 mutation | 跟随父任务 |

### 2.6 标签 (Tags)
*   **功能**: 任务支持多标签，支持标签筛选、颜色、常用标签快捷入口。
*   **技术点**:
    *   **结构**: `tags` + `task_tags` 关联表，多标签组合筛选。
    *   **解析**: 输入框识别 `#tag` 并自动创建/关联，提供去重与合并。

### 2.7 重复任务 (Recurring)
*   **功能**: 极其强大的重复规则 (e.g., "法定工作日", "每隔3天", "完成后算起").
*   **技术点**:
    *   **标准**: 严格遵循 **RFC 5545 (iCalendar)** 标准。
    *   **存储**: 数据库只存一条 `RRULE` 字符串 (如 `FREQ=MONTHLY;BYDAY=-1FR`) + `repeat_mode`。
    *   **生成**: 前端根据 `RRULE` 计算未来 N 次的虚拟实例，不真实插入数据库，直到用户完成当前实例。
    *   **例外**: 通过 `recurrence_exceptions` 记录跳过/覆盖某一次实例。

### 2.8 手动排序 / 拖拽 (Manual Order)
*   **功能**: 任务在清单 / Heading / 视图内拖拽排序，支持跨分组、跨视图拖拽（含拖到 Today / Upcoming 某天 / Someday 等）。
*   **技术点**:
    *   **排序值**: M1 用整数 `sort_order`（步长 1，重排整段）；M3 评估 LexoRank。
    *   **拖拽语义** (详见 `05_Product_Logic.md` §6.7)：
        *   拖到 Today → `when_type=1`, `due_date=today`
        *   拖到 This Evening → `when_type=2`, `evening=true`
        *   拖到 Upcoming 某天 → `when_type=4`, `due_date=该日期`
        *   拖到 Anytime / Someday / Inbox → 设对应 `when_type`
        *   拖到 Project / Heading → 改 `project_id` / `heading_id`

### 2.9 多选与批量操作（M3）
*   **功能**: 桌面 Shift/Cmd 多选；移动长按进入多选模式。
*   **批量动作**: 移到项目 / 设 When / 设 Deadline / 加标签 / 删除 / 复制。

### 2.10 Markdown Notes（M3）
*   **功能**: 任务详情中的富文本备注（替代旧 `content` 字段）。
*   **技术点**: 评估 `flutter_quill` 或 `super_editor`。同步以 Markdown 文本传输。

## 3. 日历视图 (Calendar)

### 3.1 Upcoming 视图（Things 风）
*   **功能**: 按日期分组的任务列表，顶部固定迷你月历 grid（桌面/平板）。
*   **技术点**:
    *   **数据源**: `watchPlanTasks()`（`when_type=4` 且 `due_date > today`）。
    *   **分组**: 核心 ±7 天逐日展示，超出按月分组。
    *   **Deadline 标记**: 任意视图均显示红色 "⚑" 徽标，临近 deadline (≤3 天) 自动置顶。

### 3.2 视图融合（M4 评估）
*   **功能**: 将任务显示在日历网格中，支持月视图、周视图、日视图。
*   **技术点**:
    *   **渲染**: 前端计算量大，需要高性能的网格布局算法。
    *   **外部日历**: 订阅 Google Calendar / Outlook (通过 `.ics` 订阅或 OAuth API)。

### 3.3 时间块 (Time Boxing，M4+)
*   **功能**: 将任务拖入日历的具体时间段，设定 `duration`。
*   **技术点**: 涉及 `start_time` 和 `end_time` 的联合索引查询。

## 4. 番茄专注 (Pomo Timer，后置)

### 4.1 计时器
*   **功能**: 25分钟专注 + 5分钟休息。
*   **技术点**:
    *   **本地计时**: 必须在本地运行，即使用户切后台或杀进程（利用系统级 Notification Service 保持状态）。
    *   **白名单**: 仅允许访问特定 App (Android 需要 `UsageStats` 权限)。

### 4.2 统计
*   **功能**: 生成专注热力图。
*   **技术点**: 简单的时序数据存储，适合存入 MySQL 或 ClickHouse。

## 5. 协作 (Collaboration，后置)

### 5.1 共享清单
*   **功能**: 邀请他人加入清单，共同编辑。
*   **技术点**:
    *   **权限模型**: `ProjectMember` 表 (Role: Owner, Editor, Viewer)。
    *   **实时性**: Akka Actor 必须向该 List 的所有在线成员广播 `WebSocket` 消息。
    *   **协作粒度**: 共享发生在 Project 层，Area 不参与协作。

### 5.2 动态指派
*   **功能**: 将任务指派给特定成员。
*   **技术点**: 任务表增加 `assignee_id` 字段。

## 6. 设备配对与同步 (Device Pairing & Sync)

### 6.1 设备配对
*   **功能**: 无账号设备配对，多端共享同一数据。
*   **技术点**:
    *   **配对码**: 短效 `pair_code/QR`（10 分钟单次使用）。
    *   **Token**: device_token + refresh token 轮换。
    *   **设备识别**: `device_id` 绑定会话，支持移除设备。

### 6.2 多端同步
*   **功能**: 本地变更实时同步到云端，多设备自动下发更新。
*   **同步实体（5 + 3 类）**:
    *   核心：Area / Project / Heading / Task / Checklist
    *   关联：Tag / TaskTag / RecurrenceException
    *   每个实体有独立 `etag` / `version` / `is_dirty`，按"实体 + 操作"打包。
*   **技术点**:
    *   **增量同步**: `checkpoint` 驱动的 delta 传输（详见 `02_Server_Design.md` §3 / §4）。
    *   **幂等键**: `client_mutation_id` (UUID) 在服务端 Redis 缓存 5 分钟。
    *   **冲突策略**: 默认 LWW（按 `update_time`）；高级模式保留冲突供用户选择。
    *   **离线合并**: 允许离线操作，联网后按 `client_seq` 顺序回放。

### 6.3 设备安全与会话
*   **功能**: Token 轮换、设备管理、移除设备/退出全部设备。
*   **技术点**:
    *   **短期 device_token** (24h JWT) + **长期 Refresh Token** (30d 滑动续期)。
    *   **刷新轮换**: 检测复用并撤销会话。
    *   **存储**: device_token 存 Keychain (iOS/macOS) / Keystore (Android) / DPAPI (Windows，M4+)。

### 6.4 Reminder 提醒同步
*   **功能**: 任意设备设置 reminder 后，所有配对设备到点都能收到提醒。
*   **技术点**:
    *   `reminder_at` 字段同步后，各设备本地各自调度 `flutter_local_notifications`。
    *   M2 阶段：服务端不直接推送，依赖客户端在线时本地调度。
    *   M3+ 评估：服务端 ReminderActor 兜底，对离线设备走 APNs / FCM。

## 7. AI 报告 (Weekly / Monthly / Yearly)

### 7.1 周报
*   **功能**: 自动汇总本周完成情况、重点任务、拖延任务、清单分布。
*   **技术点**:
    *   **指标统计**: 完成率、逾期率、专注时间、Logbook 增长。
    *   **维度**: 按 Area / Project / Tag 三个维度汇总。
    *   **摘要生成**: 模板 + LLM 生成自然语言总结。

### 7.2 月报/年报
*   **功能**: 长周期趋势分析、目标完成情况、标签热度与时间分配。
*   **技术点**:
    *   **缓存**: 周期报告可缓存，避免重复生成。
    *   **导出**: 支持导出为 Markdown/PDF。

## 8. 多端形态

| 平台 | 主要交互 | 平台特有 |
|---|---|---|
| **iPhone / Android 手机** | 底部 Tab + 全屏详情 + 长按多选 + 滑动手势 | 通知运行时权限、Magic Plus |
| **iPad / Android 平板** | 双栏 / 三栏自适应；外接键盘走桌面快捷键 | 分屏 / Slide Over |
| **macOS** | 三栏 + 全局热键 + 菜单栏整合 | 隐藏 titlebar、Carbon HotKey |
| **Windows / Linux**（M4 评估） | 三栏 + 系统托盘 | 亚克力背景（可选） |

## 9. 设计原则与边界

1. **离线可用 > 云端一致**：所有功能在断网下完整工作。
2. **三轴解耦**：When（做的时间）/ Deadline（截止时间）/ Reminder（提醒时间）独立。
3. **Subtask vs Checklist 边界清晰**：前者是任务，后者是任务内勾选清单。
4. **平台对齐而非平台一致**：每端遵循自己的设计语言，但功能完全一致。
5. **AI 不作主**：Quick Add 与报告生成的结果需用户确认。
