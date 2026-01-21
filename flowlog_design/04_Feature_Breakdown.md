# 功能模块细分 (Feature Breakdown)

## 1. 任务管理 (Core Task)

### 1.1 快速添加 (Quick Add)
*   **功能**: 输入框支持文本 + 语音 + 图片。
*   **技术点**:
    *   **NLP 解析**: 识别 "Next Friday", "Every day", "Priority High" 等关键词。
    *   **Smart Parsing**: 提取标签 (#work) 和清单 (^inbox)。

### 1.2 列表与看板 (List & Kanban)
*   **功能**: 普通列表视图与看板视图切换。
*   **技术点**:
    *   **看板**: 本质是修改任务的 `section_id` 或 `status`。
    *   **排序**: 支持按 `due_date`, `priority`, `title`, `custom` 排序。

### 1.3 重复任务 (Recurring)
*   **功能**: 极其强大的重复规则 (e.g., "法定工作日", "每隔3天", "完成后算起").
*   **技术点**:
    *   **标准**: 严格遵循 **RFC 5545 (iCalendar)** 标准。
    *   **存储**: 数据库只存一条 `RRULE` 字符串 (如 `FREQ=MONTHLY;BYDAY=-1FR`)。
    *   **生成**: 前端根据 `RRULE` 计算未来 N 次的虚拟实例，不真实插入数据库，直到用户完成当前实例。

## 2. 日历视图 (Calendar)

### 2.1 视图融合
*   **功能**: 将任务显示在日历网格中，支持月视图、周视图、日视图。
*   **技术点**:
    *   **渲染**: 前端计算量大，需要高性能的网格布局算法。
    *   **外部日历**: 订阅 Google Calendar / Outlook (通过 `.ics` 订阅或 OAuth API)。

### 2.2 时间块 (Time Boxing)
*   **功能**: 将任务拖入日历的具体时间段，设定 `duration`。
*   **技术点**: 涉及 `start_time` 和 `end_time` 的联合索引查询。

## 3. 番茄专注 (Pomo Timer)

### 3.1 计时器
*   **功能**: 25分钟专注 + 5分钟休息。
*   **技术点**:
    *   **本地计时**: 必须在本地运行，即使用户切后台或杀进程（利用系统级 Notification Service 保持状态）。
    *   **白名单**: 仅允许访问特定 App (Android 需要 `UsageStats` 权限)。

### 3.2 统计
*   **功能**: 生成专注热力图。
*   **技术点**: 简单的时序数据存储，适合存入 MySQL 或 ClickHouse。

## 4. 协作 (Collaboration)

### 4.1 共享清单
*   **功能**: 邀请他人加入清单，共同编辑。
*   **技术点**:
    *   **权限模型**: `ProjectMember` 表 (Role: Owner, Editor, Viewer)。
    *   **实时性**: Akka Actor 必须向该 List 的所有在线成员广播 `WebSocket` 消息。

### 4.2 动态指派
*   **功能**: 将任务指派给特定成员。
*   **技术点**: 任务表增加 `assignee_id` 字段。
