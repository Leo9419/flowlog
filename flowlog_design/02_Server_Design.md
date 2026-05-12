# 服务端详细设计 (Server Design)

> 服务端业务模型对齐 Things 的五级结构（Area > Project > Heading > Task > Checklist）+ 三轴时间（When / Deadline / Reminder）。所有客户端可见实体都纳入同步协议，按实体 + 操作打包推送。

## 1. 模块划分 (Spring Boot + Akka)

采用 **"双模"** 架构：Spring Boot 处理传统 Web 业务，Akka 处理实时互动业务。

### 1.1 Spring Boot 模块 (`web-server`)
负责无状态、请求-响应式的业务。
*   **Device Identity Service**: 设备注册、`device_token` 签发、设备信息维护。
*   **Pairing Service**: 生成/校验 `pair_code`，绑定/解绑设备。
*   **Session Service**: token 轮换、设备管理、会话撤销。
*   **Billing Service**: 订阅管理、支付网关回调 (Stripe/Alipay)。
*   **Resource Service**: 头像上传、附件存储 (对接 S3/OSS)。
*   **Admin API**: 后台管理接口。

### 1.2 Akka 模块 (`sync-server`)
负责长连接、高并发、状态管理。
*   **AccountActor**: 每个在线同步账户对应一个 Actor。
    *   维护账户内设备的 `WebSocket` 连接句柄。
    *   缓存账户的 `LastSyncId`。
    *   处理 `SyncRequest`，计算增量数据。
    *   校验 `DeviceHandshake`，绑定 `device_id` 与 `account_id`。
*   **CollaborationActor**: 处理共享清单 (Shared List) 的协作逻辑。
    *   广播变更给清单内的所有成员。
*   **ReminderActor**: 定时任务调度。
    *   利用 `Akka Quartz` 或 `Timer` 处理精确时间的任务提醒。
*   **SyncFanoutActor**: 变更广播到同一账户的其他在线设备。

### 1.3 AI Report Service
负责周报/月报/年报的生成与缓存。
*   接收定时 Job 触发或客户端按需请求。
*   汇总统计数据，调用 LLM，生成结构化摘要。
*   结果写入 `ai_reports`，支持版本更新。

### 1.4 Device Auth & Pairing 细则
*   **Device Token**: JWT，默认 24 小时有效期，包含 `device_id`/`account_id`/`scope`。
*   **Refresh Token**: 随机不可预测字符串，默认 30 天有效期（滑动续期），数据库只存 hash。
*   **轮换策略**: 每次刷新签发新的 refresh token；允许 2 分钟重试窗口；检测复用即撤销该设备全部会话。
*   **配对码**: `pair_code` 短效（10 分钟）+ 单次使用。
*   **会话管理**: 支持设备列表与单设备退出、全设备退出。
*   **WebSocket 鉴权**: 握手携带 `device_token`，过期则关闭连接并要求刷新。
*   **安全策略**: 请求限流、设备指纹校验、token 绑定设备。
*   **后续可选**: 账号绑定与第三方登录（非 MVP）。

## 2. 数据库设计 (ER 模型)

核心表结构设计 (MySQL)。

### 2.1 同步账户 (Sync Account)
```sql
CREATE TABLE `sync_accounts` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` tinyint(4) DEFAULT 0, -- 0:Normal, 1:Disabled
  PRIMARY KEY (`id`)
);
```

### 2.2 设备与会话 (Device & Session)
```sql
CREATE TABLE `devices` (
  `id` varchar(36) NOT NULL, -- UUID
  `account_id` bigint(20) NOT NULL,
  `platform` varchar(32) NOT NULL, -- ios/android/web/macos/windows
  `model` varchar(64) DEFAULT NULL,
  `push_token` varchar(255) DEFAULT NULL,
  `last_seen` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account` (`account_id`)
);

CREATE TABLE `device_sessions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `account_id` bigint(20) NOT NULL,
  `device_id` varchar(36) NOT NULL,
  `refresh_token_hash` varchar(128) NOT NULL,
  `device_token_jti` varchar(64) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `ip` varchar(64) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_account_device` (`account_id`, `device_id`)
);
```

### 2.3 配对码 (Pairing Codes)
```sql
CREATE TABLE `pairing_codes` (
  `code` varchar(16) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `device_id` varchar(36) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  PRIMARY KEY (`code`),
  KEY `idx_account` (`account_id`)
);
```

### 2.4 同步状态 (Sync State)
```sql
CREATE TABLE `sync_state` (
  `account_id` bigint(20) NOT NULL,
  `device_id` varchar(36) NOT NULL,
  `last_checkpoint` bigint(20) NOT NULL DEFAULT 0,
  `last_full_sync_at` datetime DEFAULT NULL,
  PRIMARY KEY (`account_id`, `device_id`)
);
```

### 2.5 区域 (Area)
```sql
CREATE TABLE `areas` (
  `id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `name` varchar(128) NOT NULL,
  `icon_name` varchar(64) DEFAULT NULL,
  `sort_order` bigint(20) DEFAULT 0,
  `status` tinyint(4) DEFAULT 0,        -- 0:Normal, 1:Deleted
  `etag` varchar(64) NOT NULL,
  `version` bigint(20) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account` (`account_id`),
  KEY `idx_sync` (`account_id`, `update_time`)
);
```

### 2.6 清单 (Project / List)
```sql
CREATE TABLE `projects` (
  `id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `area_id` bigint(20) DEFAULT NULL,    -- 归属 Area（nullable）
  `name` varchar(128) NOT NULL,
  `color` varchar(32) DEFAULT NULL,
  `icon_name` varchar(64) DEFAULT NULL,
  `notes` text,
  `when_type` tinyint(4) DEFAULT 0,     -- 项目本身的 When（与 Task 同义）
  `deadline` datetime DEFAULT NULL,     -- 项目截止日
  `sort_order` bigint(20) DEFAULT 0,
  `is_shared` tinyint(1) DEFAULT 0,
  `version` bigint(20) NOT NULL,        -- 乐观锁版本号
  `status` tinyint(4) DEFAULT 0,        -- 0:Active, 1:Completed, 2:Cancelled, 3:Deleted
  `completed_at` datetime DEFAULT NULL,
  `etag` varchar(64) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account` (`account_id`),
  KEY `idx_account_area` (`account_id`, `area_id`),
  KEY `idx_sync` (`account_id`, `update_time`)
);
```

### 2.7 项目分节 (Heading)
```sql
CREATE TABLE `headings` (
  `id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `project_id` bigint(20) NOT NULL,
  `title` varchar(256) NOT NULL,
  `sort_order` bigint(20) DEFAULT 0,
  `archived_at` datetime DEFAULT NULL,
  `etag` varchar(64) NOT NULL,
  `version` bigint(20) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_project` (`project_id`),
  KEY `idx_sync` (`account_id`, `update_time`)
);
```

### 2.8 任务 (Task) - 核心表
```sql
CREATE TABLE `tasks` (
  `id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `project_id` bigint(20) DEFAULT NULL,        -- 所属清单（Inbox 时为 NULL）
  `heading_id` bigint(20) DEFAULT NULL,        -- 项目内分节
  `parent_id` bigint(20) DEFAULT NULL,         -- 父任务（Subtask）
  `title` varchar(512) NOT NULL,
  `notes` mediumtext,                          -- Markdown 备注（替代旧 content）
  `priority` tinyint(4) DEFAULT 0,             -- 0:None, 1:Low, 3:Medium, 5:High

  -- ============ 三轴时间 ============
  `when_type` tinyint(4) DEFAULT 0,            -- 0=none, 1=today, 2=evening, 3=someday, 4=scheduled
  `due_date` datetime DEFAULT NULL,            -- 计划日期（与 when_type=4 配合）
  `deadline` datetime DEFAULT NULL,            -- 必须前完成（与 when_type 解耦）
  `reminder_at` datetime DEFAULT NULL,         -- 独立提醒时刻
  `is_all_day` tinyint(1) DEFAULT 0,
  `evening` tinyint(1) DEFAULT 0,              -- Today 视图下"This Evening"分组冗余字段
  `time_zone` varchar(64) DEFAULT NULL,        -- 任务创建时的时区

  -- ============ 重复规则 (RRULE) ============
  `repeat_rule` varchar(255) DEFAULT NULL,     -- e.g., "FREQ=WEEKLY;BYDAY=MO"
  `repeat_mode` varchar(16) DEFAULT NULL,      -- 'BY_DUE' | 'BY_COMPLETE'
  `repeat_until` datetime DEFAULT NULL,

  -- ============ 状态 ============
  `status` tinyint(4) DEFAULT 0,               -- 0:Todo, 1:Done, 2:Deleted
  `completed_time` datetime DEFAULT NULL,
  `in_logbook` tinyint(1) DEFAULT 1,           -- 完成后是否进 Logbook

  -- ============ 排序与同步 ============
  `sort_order` bigint(20) DEFAULT 0,
  `etag` varchar(64) NOT NULL,                 -- 同步指纹
  `version` bigint(20) NOT NULL,               -- 乐观锁
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_project` (`project_id`),
  KEY `idx_heading` (`heading_id`),
  KEY `idx_parent` (`parent_id`),
  KEY `idx_account_when` (`account_id`, `when_type`),
  KEY `idx_account_due` (`account_id`, `due_date`),
  KEY `idx_account_deadline` (`account_id`, `deadline`),
  KEY `idx_account_reminder` (`account_id`, `reminder_at`),  -- ReminderActor 扫描
  KEY `idx_sync` (`account_id`, `update_time`)               -- 增量同步核心索引
);
```

### 2.9 任务勾选项 (Checklist)
```sql
CREATE TABLE `checklists` (
  `id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `task_id` bigint(20) NOT NULL,
  `title` varchar(512) NOT NULL,
  `is_checked` tinyint(1) DEFAULT 0,
  `sort_order` bigint(20) DEFAULT 0,
  `etag` varchar(64) NOT NULL,
  `version` bigint(20) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_task` (`task_id`),
  KEY `idx_sync` (`account_id`, `update_time`)
);
```

> Checklist ≠ Subtask：Subtask 仍走 `tasks(parent_id)`，是独立任务对象；Checklist 是任务内的轻量勾选清单，不进入任何视图。两者的同步粒度也不同——Subtask 独立 mutation，Checklist 跟随父任务整体打包（也可拆分推送，由协议层决定）。

### 2.10 标签 (Tag)
```sql
CREATE TABLE `tags` (
  `id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `name` varchar(64) NOT NULL,
  `color` varchar(32) DEFAULT NULL,
  `sort_order` bigint(20) DEFAULT 0,
  `etag` varchar(64) NOT NULL,
  `version` bigint(20) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_name` (`account_id`, `name`),
  KEY `idx_sync` (`account_id`, `update_time`)
);

CREATE TABLE `task_tags` (
  `task_id` bigint(20) NOT NULL,
  `tag_id` bigint(20) NOT NULL,
  `account_id` bigint(20) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`task_id`, `tag_id`),
  KEY `idx_account` (`account_id`)
);
```

### 2.11 重复任务例外 (Recurrence Exception)
```sql
CREATE TABLE `recurrence_exceptions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `account_id` bigint(20) NOT NULL,
  `task_id` bigint(20) NOT NULL,
  `instance_date` datetime NOT NULL,
  `action` varchar(16) NOT NULL,        -- 'SKIP' | 'OVERRIDE'
  `override_payload` json DEFAULT NULL,
  `etag` varchar(64) NOT NULL,
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_task_instance` (`task_id`, `instance_date`),
  KEY `idx_sync` (`account_id`, `update_time`)
);
```

### 2.12 AI 报告 (AI Reports)
```sql
CREATE TABLE `ai_reports` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `account_id` bigint(20) NOT NULL,
  `period_type` varchar(16) NOT NULL, -- week/month/year
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `content_json` json NOT NULL, -- 摘要结构化内容
  `model` varchar(64) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_account_period` (`account_id`, `period_type`, `period_start`)
);
```

## 3. 接口协议 (Protobuf 定义示例)

> 同步实体扩展为 5 类：Area / Project / Heading / Task / Checklist（外加 Tag / TaskTag / RecurrenceException）。每个实体都有独立的 `etag`、`version`、`is_dirty`，按"实体 + 操作"打包推送。

```protobuf
syntax = "proto3";

// ============ 同步信封 ============

// 同步请求（Pull）
message SyncRequest {
  int64 account_id = 1;
  int64 client_checkpoint = 2; // 客户端当前拥有的最新数据版本号
}

// 同步响应（Pull 结果）
message SyncResponse {
  int64 server_checkpoint = 1;

  // 五类核心实体
  repeated Area     upserted_areas      = 2;
  repeated Project  upserted_projects   = 3;
  repeated Heading  upserted_headings   = 4;
  repeated Task     upserted_tasks      = 5;
  repeated Checklist upserted_checklists = 6;

  // 标签与关联
  repeated Tag      upserted_tags       = 7;
  repeated TaskTag  upserted_task_tags  = 8;

  // 删除（仅返回 ID + 类型）
  repeated EntityId deleted = 9;
}

message EntityId {
  EntityType type = 1;
  int64 id = 2;
}

enum EntityType {
  ENTITY_UNKNOWN   = 0;
  ENTITY_AREA      = 1;
  ENTITY_PROJECT   = 2;
  ENTITY_HEADING   = 3;
  ENTITY_TASK      = 4;
  ENTITY_CHECKLIST = 5;
  ENTITY_TAG       = 6;
  ENTITY_TASK_TAG  = 7;
  ENTITY_RECURRENCE_EXCEPTION = 8;
}

// 客户端推送变更（Push）
message MutationBatch {
  int64 account_id = 1;
  string device_id = 2;
  int64 client_checkpoint = 3;
  repeated Mutation mutations = 4;
}

message Mutation {
  string client_mutation_id = 1;       // 幂等键（客户端生成 UUID）
  EntityType entity_type = 2;
  MutationOp op = 3;
  bytes payload = 4;                   // Area / Project / Task ... 序列化字节
  int64 client_seq = 5;                // 客户端单调递增序号
}

enum MutationOp {
  OP_UPSERT = 0;
  OP_DELETE = 1;
}

message MutationAck {
  string client_mutation_id = 1;
  int64 server_id = 2;                  // upsert 后服务端 ID 回填
  string server_etag = 3;
  AckStatus status = 4;
  string error_message = 5;
}

enum AckStatus {
  ACK_OK = 0;
  ACK_CONFLICT = 1;
  ACK_REJECTED = 2;
}

// ============ 实体定义 ============

message Area {
  int64 id = 1;
  string name = 2;
  string icon_name = 3;
  int64 sort_order = 4;
  int32 status = 5;
  string etag = 6;
  int64 version = 7;
  int64 update_time = 8;
}

message Project {
  int64 id = 1;
  int64 area_id = 2;                    // 0 表示无归属
  string name = 3;
  string color = 4;
  string icon_name = 5;
  string notes = 6;
  WhenType when_type = 7;
  int64 deadline = 8;                   // 0 表示无 deadline
  int64 sort_order = 9;
  bool is_shared = 10;
  int32 status = 11;                    // 0=Active, 1=Completed, 2=Cancelled, 3=Deleted
  int64 completed_at = 12;
  string etag = 13;
  int64 version = 14;
  int64 update_time = 15;
}

message Heading {
  int64 id = 1;
  int64 project_id = 2;
  string title = 3;
  int64 sort_order = 4;
  int64 archived_at = 5;
  string etag = 6;
  int64 version = 7;
  int64 update_time = 8;
}

message Task {
  int64 id = 1;
  int64 project_id = 2;                 // 0 表示 Inbox
  int64 heading_id = 3;
  int64 parent_id = 4;                  // 子任务

  string title = 5;
  string notes = 6;                     // Markdown
  int32 priority = 7;

  // —— 三轴时间 ——
  WhenType when_type = 8;
  int64 due_date = 9;
  int64 deadline = 10;
  int64 reminder_at = 11;
  bool is_all_day = 12;
  bool evening = 13;
  string time_zone = 14;

  // —— 重复 ——
  string repeat_rule = 15;
  RepeatMode repeat_mode = 16;
  int64 repeat_until = 17;

  // —— 状态 ——
  int32 status = 18;                    // 0=Todo, 1=Done, 2=Deleted
  int64 completed_time = 19;
  bool in_logbook = 20;

  // —— 排序与同步 ——
  int64 sort_order = 21;
  string etag = 22;
  int64 version = 23;
  int64 update_time = 24;

  repeated int64 tag_ids = 25;          // 关联标签（冗余字段，便于快照分发）
}

enum WhenType {
  WHEN_NONE      = 0;
  WHEN_TODAY     = 1;
  WHEN_EVENING   = 2;
  WHEN_SOMEDAY   = 3;
  WHEN_SCHEDULED = 4;
}

enum RepeatMode {
  REPEAT_NONE        = 0;
  REPEAT_BY_DUE      = 1;
  REPEAT_BY_COMPLETE = 2;
}

message Checklist {
  int64 id = 1;
  int64 task_id = 2;
  string title = 3;
  bool is_checked = 4;
  int64 sort_order = 5;
  string etag = 6;
  int64 version = 7;
  int64 update_time = 8;
}

message Tag {
  int64 id = 1;
  string name = 2;
  string color = 3;
  int64 sort_order = 4;
  string etag = 5;
  int64 version = 6;
  int64 update_time = 7;
}

message TaskTag {
  int64 task_id = 1;
  int64 tag_id = 2;
  int64 update_time = 3;
}

// ============ 设备与会话 ============

message DeviceRegisterRequest {
  string device_id = 1;
  string platform = 2;                  // ios / ipados / android / macos / windows
  string model = 3;
}

message DeviceRegisterResponse {
  int64 account_id = 1;
  string device_token = 2;
  string refresh_token = 3;
}

message PairRequest {
  string pair_code = 1;
  string device_id = 2;
}

message PairResponse {
  int64 account_id = 1;
  string device_token = 2;
  string refresh_token = 3;
}

message DeviceHandshake {
  string device_token = 1;
  string device_id = 2;
  int64 account_id = 3;
  string client_version = 4;
}

// 服务端推送增量
message SyncPush {
  int64 server_checkpoint = 1;
  repeated Area     upserted_areas      = 2;
  repeated Project  upserted_projects   = 3;
  repeated Heading  upserted_headings   = 4;
  repeated Task     upserted_tasks      = 5;
  repeated Checklist upserted_checklists = 6;
  repeated Tag      upserted_tags       = 7;
  repeated TaskTag  upserted_task_tags  = 8;
  repeated EntityId deleted = 9;
}
```

## 4. 同步语义与冲突策略

### 4.1 增量同步索引

每张实体表都有 `(account_id, update_time)` 复合索引；客户端用 `client_checkpoint` 作为游标，服务端按 `update_time > checkpoint` 拉取所有实体的增量。

### 4.2 冲突处理（LWW + etag）

* 客户端推送 `Mutation` 时携带本地 `etag`。
* 服务端比对 `etag`：
    * 相同 → 接受变更，生成新 `etag` 与 `update_time`。
    * 不同 → 默认 LWW（按 `update_time`），服务端版本胜出，回 `MutationAck(status=CONFLICT)` + 当前服务端版本，由客户端覆盖本地。
    * 高级模式（M3+）：保留客户端写入到 `conflict_log` 表，UI 提示用户手动选择。

### 4.3 实体级幂等

* `client_mutation_id`（UUID）作为幂等键，服务端 Redis 缓存 5 分钟，重复推送直接返回上次 Ack。
* 删除走"软删除 + 同步标记"，永久删除单独走管理 API。

### 4.4 Reminder 调度

* `reminder_at` 是服务端的"提醒时刻"事实来源。
* 各设备在收到任务推送后，**本地各自调度本地通知**（`flutter_local_notifications`）。
* 服务端不直接发推送通知（M2 阶段），仅在 reminder 到点时通过 Push Notification Service 兜底（M3+ 评估）。
