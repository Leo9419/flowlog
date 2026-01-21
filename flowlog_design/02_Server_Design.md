# 服务端详细设计 (Server Design)

## 1. 模块划分 (Spring Boot + Akka)

采用 **"双模"** 架构：Spring Boot 处理传统 Web 业务，Akka 处理实时互动业务。

### 1.1 Spring Boot 模块 (`web-server`)
负责无状态、请求-响应式的业务。
*   **Auth Service**: 注册、登录、OAuth2 集成、Token 签发 (JWT)。
*   **Billing Service**: 订阅管理、支付网关回调 (Stripe/Alipay)。
*   **Resource Service**: 头像上传、附件存储 (对接 S3/OSS)。
*   **Admin API**: 后台管理接口。

### 1.2 Akka 模块 (`sync-server`)
负责长连接、高并发、状态管理。
*   **UserActor**: 每个在线用户对应一个 Actor。
    *   维护用户的 `WebSocket` 连接句柄。
    *   缓存用户的 `LastSyncId`。
    *   处理 `SyncRequest`，计算增量数据。
*   **CollaborationActor**: 处理共享清单 (Shared List) 的协作逻辑。
    *   广播变更给清单内的所有成员。
*   **ReminderActor**: 定时任务调度。
    *   利用 `Akka Quartz` 或 `Timer` 处理精确时间的任务提醒。

## 2. 数据库设计 (ER 模型)

核心表结构设计 (MySQL)。

### 2.1 用户与基础 (User & Settings)
```sql
CREATE TABLE `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) NOT NULL,
  `email` varchar(128) DEFAULT NULL,
  `password_hash` varchar(128) NOT NULL,
  `timezone` varchar(64) DEFAULT 'UTC', -- 关键：时间处理基准
  `daily_alert_time` time DEFAULT NULL, -- 每日提醒时间
  PRIMARY KEY (`id`)
);
```

### 2.2 清单 (Project / List)
```sql
CREATE TABLE `projects` (
  `id` bigint(20) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `name` varchar(128) NOT NULL,
  `color` varchar(32) DEFAULT NULL,
  `sort_order` bigint(20) DEFAULT 0, -- 用于自定义排序
  `is_shared` tinyint(1) DEFAULT 0,
  `version` bigint(20) NOT NULL, -- 乐观锁版本号
  `status` tinyint(4) DEFAULT 0, -- 0:Normal, 1:Archived, 2:Deleted
  PRIMARY KEY (`id`),
  KEY `idx_user` (`user_id`)
);
```

### 2.3 任务 (Task) - 核心表
```sql
CREATE TABLE `tasks` (
  `id` bigint(20) NOT NULL,
  `project_id` bigint(20) NOT NULL, -- 所属清单
  `user_id` bigint(20) NOT NULL,
  `parent_id` bigint(20) DEFAULT NULL, -- 父任务 ID
  `title` varchar(512) NOT NULL,
  `content` text, -- 备注/描述
  `priority` tinyint(4) DEFAULT 0, -- 0:None, 1:Low, 3:Medium, 5:High
  
  -- 时间管理
  `start_date` datetime DEFAULT NULL,
  `due_date` datetime DEFAULT NULL,
  `is_all_day` tinyint(1) DEFAULT 0,
  `time_zone` varchar(64) DEFAULT NULL, -- 任务创建时的时区
  `reminder` varchar(255) DEFAULT NULL, -- 提醒规则 JSON
  
  -- 重复规则 (RRULE)
  `repeat_rule` varchar(255) DEFAULT NULL, -- e.g., "FREQ=WEEKLY;BYDAY=MO"
  
  -- 同步与状态
  `status` tinyint(4) DEFAULT 0, -- 0:Todo, 1:Done, 2:Deleted
  `completed_time` datetime DEFAULT NULL,
  `sort_order` bigint(20) DEFAULT 0,
  `etag` varchar(64) NOT NULL, -- 同步指纹
  `update_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  PRIMARY KEY (`id`),
  KEY `idx_project` (`project_id`),
  KEY `idx_sync` (`user_id`, `update_time`) -- 增量同步核心索引
);
```

## 3. 接口协议 (Protobuf 定义示例)

```protobuf
syntax = "proto3";

// 同步请求
message SyncRequest {
  int64 user_id = 1;
  int64 client_checkpoint = 2; // 客户端当前拥有的最新数据版本号
}

// 同步响应
message SyncResponse {
  int64 server_checkpoint = 1; // 服务端最新版本号
  repeated Task created_tasks = 2;
  repeated Task updated_tasks = 3;
  repeated int64 deleted_task_ids = 4; // 只返回 ID
}

message Task {
  int64 id = 1;
  string title = 2;
  int64 due_date = 3;
  // ... 其他字段
}
```
