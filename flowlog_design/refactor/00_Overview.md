# FlowLog 重构总览（Things 对齐 + 多端化）

> 本目录是面向 Things 风格 UI 与多端（iOS / iPadOS / Android / macOS）支持的重构设计文档集合。所有改动以里程碑（M1–M4）为单位推进，每个 M 的细节文档独立成文。

## 1. 重构目标

| 维度 | 目标 |
|---|---|
| 平台 | macOS（已有）+ iOS / iPadOS（新增）+ Android（完整化）四端可用 |
| UI 风格 | 对齐 Things 3/4：极简留白、圆形 checkbox、SF/Inter 字体、彩色项目图标、淡阴影 |
| 视图体系 | Inbox / Today（含 This Evening）/ Upcoming / Anytime / Someday / Logbook + Areas/Projects |
| 数据模型 | 引入 Area / Heading / Checklist；Tasks 加 whenType / deadline / reminderAt / notes |
| 交互 | Quick Entry 悬浮卡 / Magic Plus / 拖拽排序 / 多选 / Markdown notes |
| 同步 | 沿用 `07_Current_Technical_Architecture.md` 已规划的本地优先 + 后台同步 |

## 2. 里程碑

| 阶段 | 范围 | 关联文档 | 时长估计 |
|---|---|---|---|
| **M1** | 数据模型升级 + iOS/Android 平台补齐 + 自适应 Shell + 主题 token | `M1_01` ~ `M1_05` | 1–2 周 |
| **M2** | 视图重构：Sidebar / Today / Upcoming / Anytime / Someday / Logbook / TaskRow / Detail | M2_*（待写） | 2–3 周 |
| **M3** | 交互：Quick Entry / 拖拽排序 / 多选 / Magic Plus / Markdown notes / Checklist UI | M3_*（待写） | 2 周 |
| **M4** | 视觉打磨 + 平台细节：动画、字体、Material You、macOS 窗口装饰、通知策略 | M4_*（待写） | 1–2 周 |

## 3. M1 文档索引

- `M1_01_Data_Model.md` — 表结构、字段、Drift migration、查询 API
- `M1_02_iOS_Setup.md` — iOS / iPadOS 工程脚手架、Info.plist、通知与热键平台抽象
- `M1_03_Android_Polish.md` — SDK 升级、权限、Material You、通知请求流程
- `M1_04_Adaptive_Shell.md` — 三档断点 Shell、Sidebar、DetailPane、SelectionStore
- `M1_05_Theme_Tokens.md` — Spacing / Typography / Radii / ColorScheme token

## 4. 设计原则

1. **本地优先（local-first）**：所有改动不破坏离线可用性，同步字段（`isDirty`、`serverId`）一并加好。
2. **代码级共享**：四端共用一份 Flutter 代码，平台差异收敛在 `lib/platform/` 与 `lib/services/` 的接口抽象后。
3. **小步快跑**：每个 M1 任务独立 commit，确保 `flutter run -d macos` 在任一中间状态都能启动。
4. **不返工**：M1 的数据模型一次到位（Area / Heading / Checklist / whenType / deadline 全加），避免 M2 视图层重构时再改 schema。
5. **保留旧视图**：M1 不删 `today_page.dart` 等旧文件，仍嵌入新 Shell；M2 替换。

## 5. 受影响的设计文档

M1 完成后需要回写：
- `flowlog_design/03_Client_Design.md` — 新增 Area/Heading/Checklist 模型，加章节"自适应 Shell"
- `flowlog_design/05_Product_Logic.md` — 加 When / Deadline 双轴说明、Anytime/Someday/Logbook 视图
- `flowlog_design/07_Current_Technical_Architecture.md` — 标注 M1 完成项
- `flowlog_design/08_Area_Project_Function_Design.md` — Area / Project / Heading 的功能定义、视图与 M2 落地范围

## 6. 验收（M1 整体）

1. `flutter run -d macos` / `-d ios` / 真机 Android 三端启动到自适应 Shell。
2. 旧数据库升级后任务数据零丢失，`notes` / `whenType` 已正确填充。
3. 三张新表（Areas / Headings / Checklists）能 CRUD，单元测试覆盖。
4. macOS 窗口拖动时三档布局（mobile / tablet / desktop）切换流畅。
5. Android 13+ 与 iOS 启动后能正确请求通知权限。
6. 现有功能（Today / Inbox / Upcoming / 全局热键 / AI / 通知）功能不回退。
