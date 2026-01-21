# 客户端详细设计 (Client Design)

## 1. 核心架构模式：离线优先 (Local-First)

与传统 App 不同，TickTick 类应用的操作**不需要等待网络回调**。
UI 只与本地数据库交互，后台 Sync Engine 负责将本地变更同步到云端。

### 1.1 架构分层
*   **UI Layer (Flutter Widgets)**: 响应式 UI，监听本地数据库流 (Stream)。
*   **State Management (BLoC / Provider)**: 处理业务逻辑，调用 Repository。
*   **Repository Layer**: 决定数据来源，但 99% 情况直接读写 Local DB。
*   **Local Data Source (SQLite)**: 单一事实来源 (Source of Truth)。
*   **Remote Data Source (API)**: 仅由 Sync Engine 调用。

## 2. 同步引擎 (Sync Engine) 设计

这是客户端最复杂的组件，负责解决“多端冲突”和“断网重连”。

### 2.1 变更队列 (Mutation Queue)
当用户创建任务时：
1.  生成临时的 UUID。
2.  写入 SQLite `tasks` 表，标记 `sync_status = dirty`。
3.  写入 SQLite `mutations` 表 (记录操作日志: `CREATE_TASK`, `payload`).
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

## 3. 本地数据库 Schema (SQLite)

除了业务表 (Tasks, Projects)，需要额外的同步辅助字段。

```sql
-- 本地任务表
CREATE TABLE local_tasks (
    id TEXT PRIMARY KEY, -- 可能包含临时 UUID
    server_id INTEGER, -- 对应的服务端 ID
    title TEXT,
    ...
    dirty_flag BOOLEAN DEFAULT 0, -- 是否未同步
    deleted_flag BOOLEAN DEFAULT 0, -- 软删除标记
    last_modified INTEGER
);

-- 变更日志表
CREATE TABLE mutations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_type TEXT, -- 'CREATE', 'UPDATE', 'DELETE'
    entity_table TEXT,
    entity_id TEXT,
    payload TEXT, -- JSON 格式的变更内容
    created_at INTEGER
);
```

## 4. 关键交互细节

*   **智能识别 (NLP)**: 客户端集成 NLP 库 (如 `Duckling` 的 WASM 版或简易正则库)，在用户输入时实时高亮时间词汇 (如 "明天下午3点")，并在提交时自动转换为 `due_date`。
*   **拖拽排序**: 修改本地 `sort_order` 字段。
    *   算法：使用浮点数或大整数间隙 (Lexicographical Rank) 避免重排整个列表。
    *   例如：A(1000), B(2000)。将 C 拖到中间，C 的 order = (1000+2000)/2 = 1500。
