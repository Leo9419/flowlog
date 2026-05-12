# FlowLog AI Assistant 设计方案

**Status**: Approved (brainstorming)
**Date**: 2026-05-11
**Owner**: maweilong
**Scope**: 在现有 AI 能力(Quick Add 文本/图片、AI Chat、周/月/年报)之上,新增 4 类 AI 助手能力,并统一抽象 AI Core 共享层。
**Reference**: `flowlog_design/06_AI_Design.md`、`flowlog_design/05_Product_Logic.md`、`flowlog_design/01_Architecture_Overview.md`

---

## 0. 决策摘要(从用户头脑风暴中固化)

| 决策 | 结论 |
|---|---|
| 目标方向 | 4 个全做:Agentic Chat / 智能自动排程 / 智能整理与拆分 / 每日教练 |
| 架构形态 | 方案 A:AI Assistant Hub 统一架构 |
| 信任模型 | 分级信任:low 免确认+Undo / medium 短弹窗 / high 强制预览 |
| Local 范围 | 仅轻量能力本地可用:Triage/Split/Coach 晨晚可 Local;Chat/AutoPlan/Coach 长期 cloud-only |
| 自动排程深度 | 半自动:用户触发,改 when_type/due_date,不引入时间块/estimated_duration |
| `ai_evening_review_enabled` 默认 | false(用户主动开) |
| `ai_suggestion_rules` 同步 | 走现有同步管道(跨设备一致) |
| 第三种 Provider:Claude Code / Codex CLI | 是,Phase 1.5 加入;Dart 原生 MCP server(in-process,SSE);桌面端 only;Codex 路径后置 |

---

## 1. AI Core 架构(共享层)

### 1.1 Tool Registry

所有 AI 可调用的能力在 `lib/services/ai/tool_registry.dart` 中声明。每个工具:
- `name`(LLM function calling 用)
- `params_schema`(JSON Schema,既给 LLM 也用于本地校验)
- `trust_level`: `low` / `medium` / `high`
- `execute(params, ctx) → ToolResult`(纯函数,不直接写 UI)
- `preview(params, ctx) → PreviewModel`(medium/high 用,渲染"将要发生什么")

**完整工具目录(across all phases)**:

| 类别 | Trust | 工具 | 引入 Phase |
|---|---|---|---|
| 读 | — | `search_tasks` / `get_view_tasks(view)` / `get_today_summary` / `get_overdue` / `get_completed_in_range` | Phase 1 |
| 读 | — | `get_completion_stats(range)` / `get_project_progress(range)` | Phase 4 |
| 写-low | low | `set_when` / `set_tags` / `set_priority` / `complete` | Phase 1 |
| 写-low | low | `reorder_within_list` | Phase 2 |
| 写-medium | medium | `create_task` / `move_to_project` / `set_deadline` / `set_reminder` | Phase 1 |
| 写-medium | medium | `create_heading` | Phase 2 |
| 写-medium | medium | `bulk_set_when` | Phase 3 |
| 写-high | high | `delete` / `bulk_update(filter, changes)` | Phase 1 |
| 写-high | high | `split_into_subtasks` / `suggest_categorize` / `merge_tasks` | Phase 2 |

> 共 23 个工具。Phase 1 起步集 15 个(reads 5 + low 4 + medium 4 + high 2);Phase 2 +5;Phase 3 +1;Phase 4 +2。

**关键约束**:所有写工具通过 Drift DAO 写入,复用现有 mutation pipeline(写本地 + `is_dirty` + sync queue),AI 不绕过同步层。

### 1.2 Trust Policy

| Trust | 默认行为 |
|---|---|
| low | 立即执行 + Today/Chat 顶部 5 秒 Undo Banner |
| medium | Toast "AI 改了 N 项,撤销?" + 5 秒 |
| high | 预览面板,必须点"应用" |

- 每条工具的默认级别可在设置中按项调整(`ai_trust_overrides`)
- Chat 内可临时"信任本轮全部动作"(仅当前会话生效)

### 1.3 Suggestion Queue(统一审批通道)

SQLite 表 `ai_suggestions`(详见 §3)。三种状态:`pending` / `accepted` / `rejected`,持久化(关 App 不丢)。`pending` 超 7 天自动 `expired`。

同一组 `SuggestionCard` Widget 在 Today / Chat / AutoPlan 中复用。支持批量"全部接受 / 全部拒绝"。

### 1.4 Plan/Execute Loop

Agentic Chat 与 AutoPlan 共用:
1. **Plan**:LLM 根据用户意图 + 当前上下文,产出工具调用序列(可多步)
2. **Execute**:按 trust_level 分流——low 立即执行;medium/high 写入 Suggestion Queue
3. **Reply**:用自然语言总结做了什么(引用 Suggestion ID)
4. **失败回退**:任一步骤失败,整轮已自动应用的 low 动作回滚

### 1.5 AI Action Log(独立 Undo 栈)

所有 AI 触发的写入进 `ai_action_log`,与普通用户 Undo 分离。设置 → AI → 操作历史:可查最近 100 条,任意撤销。

### 1.6 Privacy Filter

**默认上传**:`title` / `when_type` / `due_date` / `deadline` / `priority` / `project_name` / `tag_names` / `completed_at`

**绝不上传**:`device_id` / `account_id` / `etag` / 任何系统标识符

**默认不上传**:`notes`(除非用户在该轮 Chat 中勾选"包含备注")

**高隐私模式**(`ai_high_privacy_mode = true`):`tag_names` 与 `project_name` 替换为 hash6(`tag_a3f8b2`);`notes` 强制不传;Chat 输入框上方显示红色提示条。

---

## 2. 4 个 Surface 的功能设计

### 2.1 Surface ① Agentic AI Chat(升级现有 `ai_chat_page.dart`)

**入口**:现有 AI Tab。

**核心升级**:从"只读问答"变为"可执行"——LLM 通过 Tool Registry 多步执行。

- **消息流**:用户 → AI "思考"(可折叠 trace)→ 内联 SuggestionCard(若 medium/high)→ AI 自然语言总结
- **Quick Action chips**:📋 清理 Inbox / 📅 为今天排程 / 🌙 今日复盘 / 📊 周报 / 📊 月报 / 📊 年报
- **Slash commands**:`/plan today` / `/cleanup inbox` / `/review` / `/find <kw>`
- **上下文 chip**:聊天框上方显示作用域(可改:"全部任务" / "仅 Today" / "仅 @工作")
- **工具调用 trace**:默认折叠,debug 模式下完整可见
- **"信任本轮"按钮**:临时把 medium 降为 low(只本轮)
- **会话持久化**:`ai_conversations` + `ai_messages`,修复当前内存 List 关 App 丢失的 bug

**Provider**:cloud-only。Local 模式下输入框禁用 + 提示切换。

### 2.2 Surface ② Suggestion Cards(嵌入视图)

**入口位置**:

| 位置 | 触发条件 | 内容 |
|---|---|---|
| Today 顶部 AI 助手区(可折叠) | 每日首次进入 | 晨间简报 + "为今天排序" |
| Today 顶部 AI 助手区 | 实时 | "N 条新 Inbox 可自动分类" |
| Inbox 顶部 | ≥3 条未分类 | "AI 整理 N 项 Inbox"按钮 |
| Project 顶部 | >15 任务且语义相近 | "建议拆分为 Heading"按钮 |
| 任意视图 | 任务 7 天未动 | "是否仍要做"卡(纯规则,不调 LLM) |

**卡片结构**:标题 + 摘要 + Preview(展开看具体修改)+ 四动作:✅ 接受 / ❌ 拒绝 / ✏️ 调整 / 🙈 不再建议这类

**Provider**:首选 Local Ollama(JSON-mode);失败/未配置 → fallback 到 cloud(`ai_local_fallback_to_cloud`)。

### 2.3 Surface ③ Auto-Plan 抽屉

**入口**:Today / Upcoming 右上角"自动排程"按钮、`Cmd+Shift+P`、Chat `/plan today`。

**抽屉结构**:
- **顶部**:范围选择(今天 / 明天 / 本周末 / 本周 / 自定义日期范围)
- **中部**:LLM 方案按目的地分组——
  - 📅 进 Today(N 条)
  - 📅 进 Upcoming/具体日期(N 条)
  - 💤 降级 Someday(N 条)
  - ⚠️ 标 Deadline 临近(N 条)
- **底部**:`应用所选` / `全部接受` / `重新规划`

**LLM 约束**(prompt 中固定):
- 输入裁剪:Inbox + Anytime + Someday + Today,共 ≤80 任务(超出按 priority + 创建时间排序裁剪)
- 输出:每项一个 `{ task_id, when_type, due_date, reason }`
- 硬约束:Today 不超过 N 条(`ai_today_max_tasks`,默认 7);**所有逾期项强制进 Today**;含 deadline ≤ 3 天的强制进 Today
- 后处理校验:任何违反硬约束的 LLM 输出由客户端纠正
- **不**改写 deadline / reminder / priority

**Provider**:cloud-only。

### 2.4 Surface ④ Daily Coach

**三个呈现入口**:

#### a) Today 顶部 晨间简报卡
- 每天首次进入展开,后续折叠为一行
- 今日 X 任务 / Y 逾期 / Z 高优
- "建议先做" 3 条(算法:priority desc + deadline asc + 上次未完成次数 desc)
- 一行 LLM 生成摘要文案(跟随 locale)

#### b) 晚间反思推送(默认关)
- 默认 21:00(`ai_evening_review_time`),设置中可调
- 本日完成 X/Y,未完成项点击勾选原因(精力不足/没时间/事情变了)
- 一键:"明日继续 / 推进 Someday / 调整 deadline"
- LLM 生成两三句反思文案

#### c) Coach 抽屉(单独入口:Today 顶部"教练"按钮)
- 本周 vs 上周完成度对比图
- 各 Project 进度堆叠
- 长期洞察:"周四完成率最低 / @工作 任务平均 2.3 天完成 / 习惯模式…"

**Provider**:晨/晚 → Local 可用;长期洞察 → cloud-only。

---

## 3. 数据模型变更

**设计原则**:Task / Project / Tag 等核心表不动;AI 表本地 only,除 `ai_suggestion_rules`(走同步);AI 触发的写入复用现有 mutation pipeline;Drift schemaVersion 9 → 10。

### 3.1 新增 Drift 表(本地)

#### `ai_suggestions`

```dart
TextColumn  id              // UUID
TextColumn  surface         // 'chat' | 'today' | 'inbox' | 'project' | 'autoplan'
TextColumn  tool_name
TextColumn  args_json
TextColumn  preview_text
TextColumn  preview_json
TextColumn  status          // 'pending' | 'accepted' | 'rejected' | 'expired'
TextColumn  rejection_reason
DateTimeColumn created_at
DateTimeColumn resolved_at
TextColumn  conversation_id
```
- 索引:`(status, created_at)`、`(surface, status)`
- `pending` 超 7 天 → `expired`

#### `ai_action_log`

```dart
TextColumn  id
TextColumn  tool_name
TextColumn  args_json
TextColumn  result_json
TextColumn  trust_level
TextColumn  origin          // 'chat' | 'autoplan' | 'card' | 'coach'
TextColumn  conversation_id
BoolColumn  undone
DateTimeColumn created_at
DateTimeColumn undone_at
```
- 最近 100 条对用户可见;裁剪时 per origin 不裁(保证每入口都能撤销最近 20 条)

#### `ai_conversations`

```dart
TextColumn   id
TextColumn   title
TextColumn   context_json
DateTimeColumn created_at
DateTimeColumn updated_at
BoolColumn   pinned
```

#### `ai_messages`

```dart
TextColumn  id
TextColumn  conversation_id  // FK
TextColumn  role             // 'user' | 'assistant' | 'tool'
TextColumn  content
TextColumn  tool_calls_json
TextColumn  tool_results_json
BoolColumn  is_error
DateTimeColumn created_at
```
> 修复 `ai_chat_page.dart` 内存 List 关 App 丢失的 bug。

#### `ai_coach_insights`

```dart
TextColumn  id
TextColumn  scope            // 'weekly' | 'monthly' | 'yearly'
DateTimeColumn period_start
DateTimeColumn period_end
TextColumn  summary_md
TextColumn  metrics_json
DateTimeColumn created_at
```
- 同 period 重新生成 → 覆盖旧记录

### 3.2 同步表(走现有同步管道)

#### `ai_suggestion_rules`

```dart
TextColumn  id
TextColumn  pattern_type  // 'tag' | 'project' | 'title_keyword' | 'tool_name'
TextColumn  pattern_value
TextColumn  scope         // 'all' | 'auto_categorize' | 'split' | ...
DateTimeColumn created_at
TextColumn  etag
BoolColumn  is_dirty
```
- 同步实体新增:`AiSuggestionRule`(服务端 schema 需对应增量)

### 3.3 AppSettings 新增字段

| Key | 类型 | 默认 | 说明 |
|---|---|---|---|
| `ai_trust_overrides` | JSON Map | `{}` | 工具级 trust 覆盖 |
| `ai_today_max_tasks` | int | 7 | AutoPlan 硬约束 |
| `ai_morning_briefing_enabled` | bool | true | 晨间简报 |
| `ai_evening_review_enabled` | bool | **false** | 晚间反思推送 |
| `ai_evening_review_time` | string | "21:00" | 反思时间 |
| `ai_high_privacy_mode` | bool | false | tags/project hash 化 |
| `ai_include_notes_default` | bool | false | Chat 默认是否带 notes |
| `ai_local_fallback_to_cloud` | bool | true | Local 失败时切 cloud |
| `ai_inbox_triage_threshold` | int | 3 | Inbox 触发整理的阈值 |
| `ai_show_tool_trace` | bool | false | Debug:展开工具调用 trace |
| `ai_cloud_model_lite` | string | "" | 可选:轻量 model(省钱) |
| `ai_cli_bridge_kind` | string | "claude_code" | `claude_code` / `codex` |
| `ai_cli_command_path` | string | "" | 空=自动 `which claude`;非空=用户覆盖 |
| `ai_cli_extra_args` | JSON Array | `[]` | 附加 CLI 参数 |
| `ai_mcp_server_port` | int | 0 | 0=随机,>0=固定(反向 MCP 用) |
| `ai_mcp_external_enabled` | bool | false | 是否对外暴露 MCP(反向集成) |
| `ai_mcp_warm_pool_seconds` | int | 300 | CLI 进程暖启动保留时长 |

### 3.4 服务端变更

**本次最小化**:
- 同步实体新增 1 个:`AiSuggestionRule`
- 其余 AI 表本地 only

**后续预留**(Phase 5+,本次不做):
- `POST /ai/chat` (SSE)
- `POST /ai/plan`

### 3.5 Drift Migration(v9 → v10)

```dart
schemaVersion: 10
// from v9:
// - create table ai_suggestions
// - create table ai_action_log
// - create table ai_conversations
// - create table ai_messages
// - create table ai_coach_insights
// - create table ai_suggestion_rules
// - add new keys to AppSettings KV store with defaults
// no data migration needed
```

---

## 4. Provider 抽象 / 隐私 / 性能 / 错误处理

### 4.1 Provider 抽象

```dart
enum ProviderKind { cloud, local, cliBridge }
enum CliBridgeKind { claudeCode, codex }

abstract class AiProvider {
  ProviderKind get kind;
  AiCapabilities get capabilities;
  Future<AiTextResult>     generate(AiTextRequest req);
  Future<AiJsonResult>     generateJson(AiJsonRequest req);
  Stream<AiToolCallEvent>  chat(AiChatRequest req);
}

class AiCapabilities {
  final bool toolCalling;
  final bool jsonMode;
  final bool streaming;
  final bool vision;
  final bool desktopOnly;   // cliBridge=true
  final int  maxContextTokens;
}
```

**Provider 实现清单**:
- `CloudOpenAiProvider`(已有 `AiCloudService` 重构后)
- `LocalOllamaProvider`(已有 `AiLocalService` 重构后)
- `ClaudeCodeProvider`(**Phase 1.5 新增**,详见 §4.6)
- `CodexProvider`(Phase 5+ 评估;Codex MCP 支持成熟后)

**能力 × Surface 矩阵**:

| Surface | 需能力 | Cloud | Local | Claude Code(桌面) | Codex(桌面) |
|---|---|---|---|---|---|
| Agentic Chat | toolCalling + streaming | ✅ | ❌ | ✅ | ⏳ Phase 5+ |
| Suggestion Card(Triage/Split) | jsonMode | ✅ | ✅ | ✅ | ⏳ |
| Suggestion Card(晨间简报) | jsonMode | ✅ | ✅ | ✅ | ⏳ |
| Auto-Plan | jsonMode 或 toolCalling | ✅ | ❌ | ✅ | ⏳ |
| Coach 晨/晚 | jsonMode | ✅ | ✅ | ✅ | ⏳ |
| Coach 长期洞察 | toolCalling 或长上下文 | ✅ | ❌ | ✅ | ⏳ |
| Quick Add(已有) | jsonMode | ✅ | ✅ | ✅ | ⏳ |
| Vision Quick Add(已有) | vision | ✅ | ❌ | ✅ | ⏳ |

> 移动端(iOS/Android)`ClaudeCodeProvider` 不可选(无法 spawn 子进程)。设置中根据平台动态隐藏。

**Provider 选择流程**:
1. 用户当前 `ai_provider`
2. Surface 所需能力,当前 provider 是否支持?
3. 不支持 → 看 `ai_local_fallback_to_cloud`,允许则切 cloud(UI 明示)
4. 否则禁用入口 + 友好提示

**Model 策略**:Auto-Plan 与 Chat 用 `ai_cloud_model`;Suggestion Card / Coach 短任务用 `ai_cloud_model_lite`(为空时回退到主 model)。Claude Code Provider 由 CLI 自身的模型设置决定,FlowLog 不传 model 参数。

### 4.2 隐私

**用户可见的数据流**:设置 → AI → 数据流日志:每次调用一行:`时间 / 入口 / Provider / model / 上行字节 / 下行字节 / 失败原因`。单条可点开看脱敏后的 request body(只看键和长度)。本地存最近 200 条,可清空 / 导出。

**首次启用警告**:用户第一次开启任何 AI 功能 → 一次性 dialog 说明上传范围,要求勾选确认。

### 4.3 性能

**Token / 上下文裁剪**:
- Auto-Plan:≤80 任务
- Chat 上下文:≤40 任务
- Coach 长期:≤200 任务(聚合统计后)
- 超限裁剪顺序:priority desc → deadline asc → created_at desc

**Chat 历史**:保留最近 8 轮(同当前实现);更早走 LLM 自摘要(Phase 2+ 可选)。

**缓存**:`ai_coach_insights` 同 period 命中即跳过 LLM;Suggestion Card 晨间简报当日不重复;Auto-Plan 不缓存。

**Streaming**:Chat 走 SSE。

**并发**:同 Surface 同时仅 1 个 in-flight;不同 Surface 互不阻塞。

### 4.4 错误处理

| 错误 | 用户文案 | 行为 |
|---|---|---|
| `not_configured` | 请先在设置中配置 AI | 跳设置页 |
| `network` | 网络异常,请稍后重试 | 自动重试 1 次(指数退避) |
| `auth` | API Key 无效 | 跳设置 + 不重试 |
| `rate_limit` | 调用过频,请稍候 | 退避 30 秒 |
| `capability_missing` | 当前 provider 不支持此功能 | 提示切换 cloud |
| `bad_json` | AI 返回格式异常 | 自动重试 1 次;再失败用户层静默 |
| `tool_failed` | 工具名 + 原因 | 整轮回滚 + Chat 中明示 |
| `cancelled` | — | 无提示 |

**Tool 执行失败**:
- low 失败 → 标 failed + Snackbar
- medium/high(已批准)失败 → 错误对话框;不影响其他已成功项
- 一轮 Plan 部分失败 → AI 在回复中明示"已完成 X 项,Y 项失败"

**LLM 返回非法 JSON**:
1. JSON Schema 校验失败
2. 用更强 prompt 重发一次(附上一轮返回 + 错误信息)
3. 再失败 → 提示"AI 没理解,请简化你的描述"

**网络断连**:Cloud Surface 全部禁用 + 顶部一行"离线中,云端 AI 不可用";Local Surface 不受影响。

### 4.5 可观测性

- 内部 debug:`ai_show_tool_trace=true` → Chat 中展开 tool call 完整 JSON
- 内部 log:打到 `flutter_logs`,可导出
- **不上报任何遥测**(local-first 隐私原则)

### 4.6 ClaudeCodeProvider 架构(Phase 1.5)

**总览**:让本机的 `claude` CLI 作为 AI 推理后端,通过 MCP 协议反向调用 FlowLog 的 Tool Registry,实现完整 Agentic Chat 体验,复用用户已有的 `claude login` 登录态。

```
┌──────────────── FlowLog Desktop App ─────────────────┐
│                                                       │
│   AI Chat / Auto-Plan / Coach UI                      │
│             │                                         │
│             ▼                                         │
│   ClaudeCodeProvider                                  │
│             │ (1) spawn claude -p ...                 │
│             │      --mcp-config /tmp/flowlog.json     │
│             │      --output-format stream-json        │
│             ▼                                         │
│   ┌────────────────────────────────────────┐         │
│   │   claude CLI (用户系统已安装,已登录)   │         │
│   └────────────────┬───────────────────────┘         │
│             (2) HTTP/SSE connect                      │
│                    ▼                                  │
│   FlowlogMcpServer  (in-process,Dart 原生)            │
│       http://127.0.0.1:<port>/sse                     │
│       │ initialize / tools/list / tools/call          │
│       ▼                                               │
│   Tool Registry (同 §1.1,共享一份)                   │
│       │  trust_policy.check → suggestion_queue.push   │
│       │  (low) → 直接执行 → Drift                     │
└───────────────────────────────────────────────────────┘
```

#### 4.6.1 启动与生命周期

- FlowLog App 启动时**不**起 MCP server(避免常驻端口)
- 用户首次发送 Chat / 触发 AutoPlan 时:
  1. 检查 MCP server 是否已起 → 没起则启动(随机本地端口,只绑 `127.0.0.1`)
  2. 写临时 `flowlog-<uuid>.mcp.json` 到 OS temp 目录
  3. `Process.start('claude', [...])`,设置 `kill on parent exit`
  4. 监听 stdout 流式 NDJSON 事件 → 解析为 `AiToolCallEvent` 流
  5. CLI 退出 → MCP server 继续保留 `ai_mcp_warm_pool_seconds` 秒(默认 300);超时关闭释放端口
- App 退出 → MCP server 强制关闭

**实际拼装的 CLI 命令**:

```bash
claude -p "$user_prompt" \
  --mcp-config /tmp/flowlog-<uuid>.mcp.json \
  --output-format stream-json \
  --verbose \
  --allowed-tools 'mcp__flowlog__*'
```

| Flag | 作用 |
|---|---|
| `-p "..."` | 非交互模式,prompt 作为参数(长 prompt 可改 stdin) |
| `--mcp-config` | 指向 FlowLog 临时配置,声明 MCP server URL + token |
| `--output-format stream-json` | 输出 NDJSON 事件流,Dart 边读边渲染 |
| `--verbose` | 工具调用细节也作为事件输出,UI 才能渲染中间步骤 |
| `--allowed-tools 'mcp__flowlog__*'` | 白名单:仅允许 FlowLog MCP 工具;禁用 Claude Code 自带 Bash/Read/Write,防止 LLM 偷跑文件系统操作 |

> `$user_prompt` 中包含 system prompt(同 §1.4 Plan/Execute 中 Cloud 版本一致的指令)+ §4.3 裁剪后的任务上下文 + 用户当轮消息。
> `--append-system-prompt` 也可用,但 prompt 拼装更可控,先用 `-p` 全量。

**`flowlog-<uuid>.mcp.json` 内容**:

```json
{
  "mcpServers": {
    "flowlog": {
      "type": "sse",
      "url": "http://127.0.0.1:<random_port>/sse",
      "headers": { "Authorization": "Bearer <one-time-token>" }
    }
  }
}
```

调用结束后,临时文件由 FlowLog 删除(每轮独立 uuid + token,防止外部进程拼到旧 token)。

**stdout NDJSON 事件示例(逐行解析)**:

```jsonl
{"type":"system","subtype":"init","tools":["mcp__flowlog__search_tasks","mcp__flowlog__set_when",...]}
{"type":"assistant","message":{"content":[{"type":"text","text":"我先查一下..."}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"mcp__flowlog__search_tasks","input":{"project":"家庭","status":"todo"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_01","content":"[...4 tasks JSON...]"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"找到 4 条,我建议..."}]}}
{"type":"result","subtype":"success","total_cost_usd":0.01,"duration_ms":3421}
```

Dart 事件映射:
| stream-json `type` | FlowLog `AiToolCallEvent` 子类型 |
|---|---|
| `system.init` | `SessionStarted(tools: [...])` |
| `assistant.message` 含 `text` | `AssistantText(text)`(逐段追加气泡) |
| `assistant.message` 含 `tool_use` | `ToolCallStarted(name, input)` |
| `user.message` 含 `tool_result` | `ToolCallCompleted(id, content)` |
| `result.success` | `SessionFinished(costUsd, durationMs)` |
| `result.error` | `SessionFailed(reason)` |

#### 4.6.2 MCP Server(Dart 原生)

**协议范围**(实现 MCP 2024-11-05 spec 最小子集):
- 传输:HTTP + SSE(`/sse` 端点,事件流;`/messages` POST)
- 方法:`initialize` / `notifications/initialized` / `tools/list` / `tools/call`
- 不实现:`resources/*` / `prompts/*`(本次不需要)

**Tool 映射**:Tool Registry 的每个工具 → 1 个 MCP tool。
- `name` 直接复用(eg `set_when`)
- `inputSchema` 用 Tool Registry 的 JSON Schema
- `description` 中包含 trust_level 说明,让 Claude Code 用户感知风险

**Trust Policy 适用**:MCP `tools/call` 时,服务端按 §1.2 分流——
- low → 直接执行,返回 result
- medium → 写入 Suggestion Queue,返回 `{ pending_suggestion_id: ... }` + 描述,让 Claude 用自然语言告诉用户"已提交 N 条待审批"
- high → 同 medium,但 description 中带 preview

**安全**:
- 只绑 `127.0.0.1`,不监听公网
- 启动时生成一次性 token,写入 mcp-config,server 校验请求 header
- App 后台/锁屏时拒绝新请求(防止误操作)

#### 4.6.3 ClaudeCodeProvider 的特殊行为

- `capabilities.toolCalling = true`(通过 MCP)
- `capabilities.streaming = true`(stream-json)
- `capabilities.jsonMode = true`(prompt 中要求 JSON)
- `capabilities.vision = true`(Claude Code 支持图片)
- `capabilities.desktopOnly = true`
- **不传 model 参数**:用 CLI 当前配置;用户在 Claude Code 自己的设置改
- **不传 API key**:用 CLI 已登录态
- `generate` / `generateJson` 也走 CLI(`-p`)+ 无 mcp-config(节省启动)
- `chat` 才挂 MCP server

#### 4.6.4 错误处理

| 情况 | 处理 |
|---|---|
| `claude` 未安装 | 检测 `which claude` 失败 → 设置中标红,引导安装 |
| 未登录 | 第一次调用解析 stderr,提示用户跑 `claude /login` |
| CLI 退出码非 0 | 解析 stderr,映射到 §4.4 错误码 |
| MCP server 启动端口冲突 | 自动换端口重试 3 次 |
| 子进程超时(默认 60s) | 强制 kill,返回 `timeout` 错误 |

#### 4.6.5 反向 MCP(顺带支持外部 Claude)

同一个 `FlowlogMcpServer` 加一个常驻模式开关(`ai_mcp_external_enabled`):
- 开启时:App 启动即起 server,绑定 `127.0.0.1:<ai_mcp_server_port>`(默认 0=随机,用户可固定)
- 用户把 `http://127.0.0.1:<port>/sse` 加到自己的 `~/.claude/mcp.json`
- 终端跑 `claude` 时即可调用 FlowLog 任务
- token 通过设置页一键复制
- 默认关闭(安全,避免误开)

#### 4.6.6 性能预估

| 操作 | 延迟 |
|---|---|
| 冷启 `claude` 子进程 | ~1-2s |
| 暖启(5 分钟内复用进程) | <300ms |
| MCP `tools/call` 单次 | <50ms(本地 HTTP) |
| 整轮 3 步工具调用 Chat | 5-10s(取决于 Claude 模型) |

> 冷启延迟通过"5 分钟暖启动池"缓解;若仍不满意,Phase 1.5 plan 中评估常驻进程方案。

---

## 5. 路线图(分阶段实施)+ 验收标准

**总原则**:每 Phase 独立可发布;一个 Phase 失败/延期不阻塞用户当前体验。每个 Phase 后续会拆出独立 implementation plan。

### Phase 1:AI Core 基础设施 + Agentic Chat MVP(2.5–3 周)

**范围**:
- AI Core:Tool Registry / Trust Policy / Suggestion Queue / AI Action Log / Privacy Filter / Provider 抽象
- 数据库:`ai_suggestions` / `ai_action_log` / `ai_conversations` / `ai_messages` / Drift migration v10
- 工具集首批(§1.1 中标注 "Phase 1" 的 15 个工具)
- Chat 升级:工具调用循环 + SSE 流式 + Suggestion Card 内联 + Slash commands(`/find` 起步)+ 上下文 chip + 持久化会话
- 设置页:AI → 操作历史 / 信任策略覆盖 / 数据流日志

**不在范围**:Suggestion Cards 嵌入视图、Auto-Plan、Coach。

**验收标准**:
1. Chat 输入「把所有 @家庭 的 inbox 任务移到 Personal Project,并把 deadline 早于今天的设成今天」→ AI 多步调用 → 预览 → 接受 → 任务正确更新
2. 网络断开 → Chat 入口禁用 + 友好提示
3. 关 App 再开,聊天历史还在;Suggestion Queue 的 pending 仍可处理
4. 撤销:任意一条 AI 写入,从设置 → 操作历史中可单条撤销
5. 高隐私模式:开启后抓包确认 tag/project 被 hash
6. 性能:Chat 首字节 < 2s;完整回复(含 3 工具调用)< 8s
7. 单元测试:每个工具有契约测试;Trust Policy 三档分流有覆盖测试

### Phase 1.5:Claude Code Provider + Dart MCP Server(1 周,可选,桌面端 only)

**前置**:Phase 1 完成(Tool Registry / Trust Policy / Suggestion Queue 已就位)。

**范围**:
- `FlowlogMcpServer`:Dart 原生 MCP server(HTTP + SSE 传输,JSON-RPC 协议),实现 `initialize` / `tools/list` / `tools/call` / `notifications/initialized`(详见 §4.6.2)
- `ClaudeCodeProvider`:`AiProvider` 实现,spawn `claude` 子进程 + stream-json + mcp-config(详见 §4.6.1–4.6.3)
- Tool Registry 到 MCP tool 的自动桥接(共用一份 schema 与执行函数)
- 设置页:AI Provider 选项新增 "Claude Code(本机)"(仅桌面端可见)
- 设置页:Claude Code 安装/登录状态检测;反向 MCP 开关 + token 复制按钮
- 暖启动进程池(5 分钟超时,可配置)

**不在范围**:Codex 路径(后置 Phase 5+);MCP `resources/*` 与 `prompts/*` 协议;持久化常驻进程。

**验收标准**:
1. 桌面端开 "Claude Code" provider → Chat 输入「列出 @家庭 项目所有任务并把 deadline 已过的设成今天」→ Claude Code 通过 MCP 调用 `search_tasks` + `bulk_update` → 用户预览 → 接受 → 任务更新正确
2. `claude` 未安装时,设置页明示并禁用入口
3. `claude` 已安装但未登录 → 第一次调用提示用户运行 `claude /login`
4. 反向 MCP:开启外部暴露后,在终端 `claude` 中可调用 FlowLog 工具(经 token 验证)
5. 安全:其他网卡 / 其他主机访问 `127.0.0.1:<port>` 失败(只绑 loopback);无 token 请求返回 401
6. 性能:暖启动 Chat 首字节 <800ms;冷启动 <3s
7. 移动端:provider 选项中不显示 "Claude Code" 项

**预估**:1 周(MCP 协议本身简单,主要是子进程管理 + 错误路径覆盖)。

### Phase 2:Suggestion Cards + Smart Triage / Split(2 周)

**范围**:
- 通用 `SuggestionCard` Widget(Chat / Today / Inbox / Project 共用)
- Today 顶部 AI 助手区(可折叠)
- Inbox 顶部"整理"按钮
- Project 顶部"建议拆分"按钮
- 新工具:`split_into_subtasks` / `suggest_categorize` / `merge_tasks` / `create_heading` / `reorder_within_list`(§1.1 标注 Phase 2 的 5 个)
- `ai_suggestion_rules` 表 + 服务端同步实体
- Local Provider 路径打通(JSON-mode + fallback to cloud)

**验收标准**:
1. Inbox ≥3 条未分类 → 顶部 Triage 卡 → 每条目的 Project 展示 → 单独接受/拒绝 → 应用后 Inbox 减少
2. 拒绝 3 次"自动分类娱乐到 工作 Project" → 系统记住,后续不再建议
3. 拒绝规则在 macOS 设置后,iOS 同步后也生效
4. 离线:Local 可用时整理正常;Local 不可用 + 允许 fallback → 切 cloud + 提示
5. Project >15 + 语义相近 → 顶部"拆为 N 个 Heading" → 接受后创建 Heading 并搬运任务

### Phase 3:Auto-Plan 抽屉(1.5–2 周)

**范围**:
- `AutoPlanSheet` 抽屉 UI
- LLM prompt 模板 + Schema 校验 + 重试逻辑
- 硬约束执行 + 后处理校验
- 卡片化方案审阅 UI(按目的地分组)
- 工具:`bulk_set_when`

**不在范围**:与系统日历集成、引入 `estimated_duration` 字段。

**验收标准**:
1. Inbox + Anytime 共 30 条 → 触发 Auto-Plan → 5 秒内出方案 → 按目的地分组 → 反选 2 条 → 应用所选 → 数据库写入正确
2. 硬约束:Today 已有 5 条 + 用户上限 7 → AI 只能再推 2 条进 Today,其余进 Upcoming
3. 逾期任务无论 LLM 如何决策都进"Today"组(后处理校验)
4. LLM 返回非法 JSON → 自动重试 1 次 → 仍失败给友好错误
5. Local provider 时入口灰显并明示"自动排程需要云端 AI"

### Phase 4:Daily Coach(2 周)

**范围**:
- Today 顶部"晨间简报"卡
- 晚间反思推送(本地通知)
- Coach 抽屉(基于 `ai_coach_insights` 缓存)
- 周/月对比图表组件
- 工具:`get_completion_stats(range)` / `get_project_progress(range)`
- 设置:简报时间 / 反思时间 / 反思推送开关

**验收标准**:
1. 用户每天首次进 Today → 当日简报 + "建议先做" 3 条 → 数据正确
2. 晚间反思 21:00 + 开启 → 收到本地通知 → 进入反思卡 → 勾选未完成原因 → 一键"明日继续"批量改 when_type
3. Coach 抽屉"本月" → 5 秒内出 markdown + 完成度柱状图;同 period 第二次打开 < 500ms(命中缓存)
4. Local-only 时:晨/晚可用;长期洞察灰显提示

### Phase 5+:候选(不在本次设计范围)

- 服务端 AI 代理(`POST /ai/chat` / `POST /ai/plan`)
- **CodexProvider**(等 Codex CLI 的 MCP 支持成熟后,沿用 §4.6 架构,只换 CLI 名)
- 常驻进程优化(若 Phase 1.5 的暖启动池不够用)
- MCP 协议扩展:`resources/*`(暴露任务作为可订阅资源,实现"Claude 自动注意到新 Inbox")
- 语音输入 → Chat / Quick Add
- 系统日历集成(只读 → 避开会议时段)
- `estimated_duration` + 真正的时间块排程
- 跨任务智能搜索
- AI 习惯洞察(完成率周期、最佳工作时段)

### 总时间预估

| Phase | 工时(一人) |
|---|---|
| 1 — AI Core + Chat MVP | 2.5–3 周 |
| 1.5 — Claude Code Provider(可选) | 1 周 |
| 2 — Suggestion Cards | 2 周 |
| 3 — Auto-Plan | 1.5–2 周 |
| 4 — Daily Coach | 2 周 |
| **合计(含 1.5)** | **9–10 周** |

---

## 6. 与现有设计文档的关系

本文档**新增**对 `flowlog_design/06_AI_Design.md` 的扩展:
- §6_AI_Design.md 的"AI Chat (Cloud Only)" / "AI Reports" 章节仍然成立,本设计基于其上加入工具调用 + 多 surface
- `05_Product_Logic.md` §6.10 "AI 快速添加"、§6.11 "智能助手" 仍是入口,本设计不动这两节的语义,只升级实现
- 同步管道沿用 `01_Architecture_Overview.md` §5(Sync Flow);新表 `ai_suggestion_rules` 加入同步实体集

实施完成后,需同步更新:
- `flowlog_design/06_AI_Design.md` —— 新增 Tool Registry / Suggestion Queue / Trust Policy 章节
- `flowlog_design/05_Product_Logic.md` §6.11 —— 升级"智能助手"描述
- `flowlog_design/04_Feature_Breakdown.md` —— Phase 1-4 完成后逐项补全

---

## 7. 开放问题(实施前需在 Phase 1 plan 中确认)

| 议题 | 说明 |
|---|---|
| `ai_cloud_model_lite` 是否要做 | 设计层留口;Phase 1 可不开 UI,只读环境变量配置;Phase 2+ 再放出来 |
| Token 月度上限 | 默认无限;Phase 3+ 评估是否引入 |
| Chat `/cleanup inbox` 的具体语义 | Phase 1 以 prompt 实现,无独立工具;Phase 2 评估是否抽出 `inbox_triage_batch` 专用工具 |
| 晚间反思推送的 Android 13+ 权限路径 | 沿用 `05_Product_Logic.md` §11 已有方案,Phase 4 plan 中再细化 |

---

**End of design.**
