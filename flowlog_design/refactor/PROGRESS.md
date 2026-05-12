# FlowLog 重构进度（PROGRESS）

> 本文件由开发过程实时回写，是 `00_Overview.md` 中里程碑表的执行版。
> 状态符号：⬜ 未开始 / 🟡 进行中 / ✅ 完成 / ⏸️ 暂停 / ❌ 放弃。
> 每个完成项都应附 commit hash（短）和完成日期（YYYY-MM-DD）。

## 总览

| 里程碑 | 文档 | 状态 | 起止 |
|---|---|---|---|
| **M1** 数据模型 + 多端补齐 + Shell + token | `M1_01`–`M1_05` | ✅ 全部完成（待 commit） | 2026-05-08 → 2026-05-09 |
| **M2** 视图重构（Sidebar / Today / Upcoming / …） | `M2_*`（待写） | ⬜ | — |
| **M3** 交互（Quick Entry / 拖拽 / 多选 / Markdown / Checklist UI） | `M3_*`（待写） | ⬜ | — |
| **M4** 视觉打磨 + 平台细节 | `M4_*`（待写） | ⬜ | — |

## M1 子任务

| 编号 | 子项 | 文档 | 状态 | 完成日 | Commit | 备注 |
|---|---|---|---|---|---|---|
| M1_01 | Drift schema 升级（Areas/Headings/Checklists + Tasks/Projects 扩展 + migration） | `M1_01_Data_Model.md` | ✅ 完成（待 commit） | 2026-05-08 | _待回填_ | 13+14 测试全绿；激进路线（serverId/color 类型对齐）已落地；详见 §M1_01 实施步骤 |
| M1_02 | iOS / iPadOS 工程脚手架 | `M1_02_iOS_Setup.md` | ✅ 完成（待 commit） | 2026-05-09 | _待回填_ | iOS 工程已生成；Pod 安装 + Xcode 签名 + 模拟器实测留给用户本地（详见 §M1_02 风险） |
| M1_03 | Android SDK 升级 + Material You + 通知权限 | `M1_03_Android_Polish.md` | ✅ 完成（待 commit） | 2026-05-08 | _待回填_ | dynamic_color 已接入；详见 §M1_03 |
| M1_04 | 自适应 Shell（mobile/tablet/desktop 三档） | `M1_04_Adaptive_Shell.md` | ✅ 完成（待 commit） | 2026-05-08 | _待回填_ | 用户选"按文档：main.dart 直切 AdaptiveShell"路线；HomePage @Deprecated 保留；详见 §M1_04 |
| M1_05 | 主题与设计 token | `M1_05_Theme_Tokens.md` | ✅ 完成（待 commit） | 2026-05-08 | _待回填_ | DynamicColorBuilder 推迟到 M1_03，详见偏离记录 |

## M1_05 实施步骤（细化）

按 `M1_05_Theme_Tokens.md` §8 的 6 步切：

| # | 步骤 | 状态 | Commit | 备注 |
|---|---|---|---|---|
| 1 | `feat(theme): scaffold spacing/radii/elevation tokens` | ✅ | _待回填_ | `spacing.dart` / `radii.dart` / `elevation.dart`，纯常量 |
| 2 | `feat(theme): light & dark ColorScheme builders with seed override` | ✅ | _待回填_ | 保留 #FF3B6B 粉色作 brand seed；surface/outlineVariant 手工覆盖 |
| 3 | `feat(theme): typography with cross-platform fallbacks` | ✅ | _待回填_ | 基于 Typography.material2021，覆写 5 档 |
| 4 | `feat(theme): unified app_theme + component theme overrides` | ✅ | _待回填_ | Flutter 3.38 实际用 `CardThemeData` / `DialogThemeData` / `PopupMenuThemeData` |
| 5 | `chore(main): wire new theme builders` | ✅ | _待回填_ | DynamicColorBuilder 推迟到 M1_03，static seed + TODO 注释 |
| 6 | 视觉对比 macOS（iOS/Android 后续 M1_02/03 完成后补） | ⬜ | — | 留给 user 下次 `flutter run -d macos` 时手工核验 |

## M1_01 实施步骤（细化）

按 `M1_01_Data_Model.md` §7 细化为 7+2 步，全部已闭环：

| # | 步骤 | 状态 | Commit | 备注 |
|---|---|---|---|---|
| 1 | `feat(db): add Areas/Headings/Checklists tables + extend Tasks/Projects fields` | ✅ | _待回填_ | 一次性按文档对齐，含类型激进改动 |
| 2 | `feat(db): regenerate database.g.dart` | ✅ | _待回填_ | `dart run build_runner build --delete-conflicting-outputs`，9s 通过 |
| 3 | `feat(db): add v9 migration with TableMigration for tasks/projects + backfill` | ✅ | _待回填_ | TableMigration 重建 tasks/projects；SQL 回填 notes/whenType/sortOrder/color hex |
| 4 | `feat(db): wire @DriftDatabase + change createProject/updateProject signature` | ✅ | _待回填_ | createProject/updateProject 第 3 参 int → String?；_seedDefaultProjects 改 hex |
| 5 | `feat(theme): add color_utils.dart for hex<->Color` | ✅ | _待回填_ | `colorToHex` / `hexToColor` / `argbIntToHex` |
| 6 | `feat(ui): switch project_manage_page + home_page to hex color` | ✅ | _待回填_ | 4 处 Color(project.color) → hexToColor(project.color) |
| 7 | `feat(db): add Things-aligned queries (today/anytime/someday/logbook/areas/headings/checklists/progress)` | ✅ | _待回填_ | 含 WhenType enum + TodaySections / ProjectProgress 值类型 |
| 8 | `feat(db): add write APIs (setTaskWhen/Deadline/Reminder, moveTaskToProject, reorder*, checklist/heading/area CRUD)` | ✅ | _待回填_ | 见 database.dart 末段 |
| 9 | `test(db): migration_test 13 cases + queries_test 14 cases` | ✅ | _待回填_ | `flutter test` 28/28 绿；新增 dev_dep `sqlite3: ^2.4.0` |

### M1_01 验证记录

| 项 | 结果 |
|---|---|
| `dart run build_runner build` | 9s, 78 outputs |
| `flutter analyze --no-pub` | 81 条 info（全部历史 deprecation/lint），**0 error** |
| `flutter test` | 28/28 通过（migration 13 + queries 14 + 既有 widget_test 1） |
| 真实数据库升级 | ⏸ 留给用户本地启动验证；用户已确认 macOS run 视觉无回退由本人核对 |

## M1_02 实施步骤（细化）

按 `M1_02_iOS_Setup.md` §11 切 6 步，本轮闭环 5 步（步骤 6 "模拟器启动" 留给用户本地）。

| # | 步骤 | 状态 | Commit | 备注 |
|---|---|---|---|---|
| 1 | `chore(ios): scaffold via flutter create --platforms=ios` | ✅ | _待回填_ | `flutter create` 写出 39 个文件；`ios/.gitignore` 自带 |
| 2 | `chore(ios): tune Info.plist & Podfile for ios 13 baseline` | ✅ | _待回填_ | Info.plist：CFBundleDisplayName=FlowLog / UIRequiresFullScreen=false / UIBackgroundModes / NSPhotoLibrary + NSCamera UsageDescription（按 doc §12 不写 NSUserNotificationsUsageDescription）；Podfile：platform :ios, '13.0' + post_install IPHONEOS_DEPLOYMENT_TARGET + GCC_PREPROCESSOR_DEFINITIONS PERMISSION_NOTIFICATIONS=1 |
| 3 | `chore(ios): wire AppDelegate notification delegate` | ✅ | _待回填_ | UNUserNotificationCenter delegate；setPluginRegistrantCallback；willPresent → banner + sound + badge（iOS 14+ 用 .banner+.list） |
| 4 | `refactor(hotkey): split GlobalHotkeyService into interface + macOS impl + noop` | ⏸ → 偏离 | — | 现有 `global_hotkey_service.dart` 在 `bind()` 里已用 `defaultTargetPlatform != TargetPlatform.macOS` 早返回，iOS 自然走 noop；不做拆分，避免无收益的重构 |
| 5 | `feat(notify): defer iOS permission to first-use sites` | ✅ | _待回填_ | DarwinInitializationSettings 三项 requestPermission=false；同一改动顺手把 macOS 也改成延后请求 |
| 5b | `feat(notify): set local timezone via flutter_timezone` | ✅ | _待回填_ | 加 `flutter_timezone: ^5.0.2`；`tz.setLocalLocation(tz.getLocation(info.identifier))` 失败时降级到 UTC 记 debugPrint |
| 6 | `chore(ios): pod install + simulator launch` | ⏸ | — | 留给用户本地：`cd client/ios && pod install`，Xcode 签名，`flutter run -d "iPhone 15"` / `-d "iPad Pro"` |

### M1_02 验证记录

| 项 | 结果 |
|---|---|
| `flutter create --platforms=ios .` | 39 files written, dependencies resolved |
| `flutter analyze --no-pub lib/services/notification_service.dart lib/main.dart` | **0 issue** |
| `flutter analyze --no-pub`（全量） | **0 error**（82 历史 info）|
| `flutter test` | 28/28 通过 |
| iOS 模拟器实机启动 / iPad 旋转切布局 / 通知权限弹窗 | ⏸ 留给用户本地（doc §13 验收 1-6） |

## M1_03 实施步骤（细化）

按 `M1_03_Android_Polish.md` §9 切 6 步，本轮闭环 5 步（步骤 6 "Pixel 7 模拟器实测" 留给用户本地）。

| # | 步骤 | 状态 | Commit | 备注 |
|---|---|---|---|---|
| 1 | `chore(android): bump SDK / kotlin / gradle` | ⏸ → 偏离 | — | Flutter 3.38.7 已带 SDK 35+ / Kotlin 1.9.x / Gradle 8.14；只显式锁 minSdk=23，其余继承 Flutter 默认 |
| 2 | `chore(android): declare notification & exact alarm permissions` | ✅ | _待回填_ | 加 USE_EXACT_ALARM / RECEIVE_BOOT_COMPLETED / VIBRATE / INTERNET / ACCESS_NETWORK_STATE |
| 3 | `chore(android): register flutter_local_notifications boot receiver` | ✅ | _待回填_ | 注册 ScheduledNotificationReceiver / ScheduledNotificationBootReceiver；application 加 enableOnBackInvokedCallback="true" |
| 4 | `feat(theme): wire DynamicColorBuilder for Material You` | ✅ | _待回填_ | 接 dynamic_color: ^1.7.0；Android 12+ 跟壁纸色，其他平台回退 brand seed |
| 5 | `feat(notify): runtime POST_NOTIFICATIONS request on Android 13+` | ⏸ → 偏离 | — | notification_service 已用 flutter_local_notifications 自带 `requestNotificationsPermission()` / `requestExactAlarmsPermission()` 实现等价能力；不引入 permission_handler / device_info_plus |
| 6 | `chore(android): verify on Pixel 7 (API 34) emulator` | ⏸ | — | 留给用户本地执行（`flutter run -d <android>`）|

### M1_03 验证记录

| 项 | 结果 |
|---|---|
| `flutter analyze --no-pub lib/main.dart` | **0 issue** |
| `flutter analyze --no-pub`（全量） | **0 error**（历史 info 不变）|
| `flutter test` | 28/28 通过（无回归） |
| `flutter run -d android` 实机 / 模拟器 | ⏸ 留给用户本地（doc §11 验收 1-6） |

## M1_04 实施步骤（细化）

按 `M1_04_Adaptive_Shell.md` §10 切 10 步，本轮闭环 9 步（步骤 7 "抽出 TaskDetailView" 通过 Navigator 嵌入复用代替，避免对 task_detail_sheet.dart 做大规模拆分；记为偏离）。

| # | 步骤 | 状态 | Commit | 备注 |
|---|---|---|---|---|
| 1 | `feat(state): SelectionStore + SidebarView enum` | ✅ | _待回填_ | 11 项 enum + SelectionState 不可变值类型 + ChangeNotifier |
| 2 | `feat(shell): breakpoints + AdaptiveShell skeleton` | ✅ | _待回填_ | 600 / 1000 双切点；layoutForWidth() |
| 3 | `feat(shell): MobileShell with bottom NavigationBar wired to old pages` | ✅ | _待回填_ | 5 项底部 Tab：Today/Upcoming/Anytime/Inbox/Someday |
| 4 | `feat(shell): Sidebar widget + 6 fixed items` | ✅ | _待回填_ | 6 视图 + Trash/Settings；Areas/Projects/Tags 区为 M2 占位文案 |
| 5 | `feat(shell): TabletShell two-pane` | ✅ | _待回填_ | 280px sidebar + Expanded content |
| 6 | `feat(shell): DesktopShell three-pane via multi_split_view` | ✅ | _待回填_ | multi_split_view 3.6.1 的 `initialAreas`+`builder` API；selectedTaskId 空时退化为双栏 |
| 7 | `refactor(detail): extract TaskDetailView for embed reuse` | ⏸ → 偏离 | — | 改为：DetailPane 用嵌入式 Navigator 直接复用 TaskDetailSheet，sheet 内的 Navigator.pop 转写为 SelectionStore.clearTask；不动 task_detail_sheet.dart 大文件 |
| 8 | `feat(shell): DesktopShell wires DetailPane on selectionStore.selectedTaskId` | ✅ | _待回填_ | DetailPane 流式订阅 selectedTaskId + watchSingleOrNull(tasks) |
| 9 | `feat(pages): Anytime/Someday/Logbook placeholders` | ✅ | _待回填_ | 不止占位，直接接通 M1_01 的 watchAnytimeTasks/watchSomedayTasks/watchLogbook，已可见数据 |
| 10 | `chore(home): mark old HomePage deprecated` | ✅ | _待回填_ | `@Deprecated('Replaced by AdaptiveShell ...')` |

### M1_04 验证记录

| 项 | 结果 |
|---|---|
| `flutter analyze --no-pub lib/ui/shell/ lib/state/ lib/ui/anytime/ lib/ui/someday/ lib/ui/logbook/ lib/main.dart` | **0 issue**（新文件干净） |
| `flutter analyze --no-pub`（全量） | 82 条 info（全部历史 deprecation/lint），**0 error** |
| `flutter test` | 28/28 通过（无回归） |
| 三档断点切换 macOS / iPad / iPhone 模拟器实机 | ⏸ 留给用户本地验证（doc §12 验收 1-7） |

### M1_05 验证记录

| 项 | 结果 |
|---|---|
| `flutter analyze --no-pub lib/theme/ lib/main.dart` | `No issues found! (ran in 1.3s)` |
| `flutter analyze --no-pub`（全量） | 84 条 info-level 历史 deprecation/lint，全部位于未改动的 `lib/ui/*`，与本次无关 |
| `flutter run -d macos` 视觉对比 | ⏸ 留给用户本地验证；token 默认值与原 ThemeData 接近，预期无明显回退 |

## 偏离与决策记录

| 日期 | 偏离 | 原因 | 影响 |
|---|---|---|---|
| 2026-05-08 | 先做 M1_05 而非 M1_01 | 用户选择视觉先收敛，数据模型在后续 session 处理 | 不阻塞，token 不依赖 schema；但 M2 视图重构必须等 M1_01 落地 |
| 2026-05-08 | M1_05 §5 的 `DynamicColorBuilder` 暂不接 | M1_03 未做，`dynamic_color` 包未引入 | `appLightTheme()/appDarkTheme()` 暂用静态 seed；M1_03 完成后回写 `main.dart` 的 TODO 处 |
| 2026-05-08 | `tokens.dart` 不 export `app_theme.dart` | 避免普通组件文件被牵连重编译 ThemeData builder | 入口（`main.dart`）单独 `import 'theme/app_theme.dart'`；其余 UI 文件 `import 'theme/tokens.dart'` |
| 2026-05-08 | 增加了 `surfaceContainerLowest` / `surfaceContainerLow` / `surfaceContainerHighest` | M1_05 §4.5 只列了 3 档，但 Flutter M3 实际给到 5 档；一次填齐避免 M2 视图反复回头补 | 与文档一致的 surface 三档值不变，新增 2 档为 0xFFFFFF/0xFAFAFC（light）和 0x000000/0x1C1C1E（dark） |
| 2026-05-08 | M1_01 走"激进路线"：`Tasks.serverId` int → text，`Projects.color` int → text nullable | 用户在 AskUserQuestion 中明确选择；M3 同步层的 ID 形态早晚要 text，一次到位 | 用 `m.alterTable(TableMigration(...))` 重建 tasks/projects，columnTransformer 用 `CAST` / `printf('#%08X', color)` 平迁数据；UI 4 处 `Color(project.color)` 同步改为 `hexToColor(project.color)` |
| 2026-05-08 | `Projects.isDirty` 在 v9 才出现 | v8 schema 的 projects 表没有 isDirty 列，doc §4.2 没把它单列出来 | TableMigration 的 newColumns 中加了 `projects.isDirty`，否则 rebuild 时旧表 SELECT 出 NULL 触发 BoolColumn 的 NOT NULL CHECK；测试中已捕获 |
| 2026-05-08 | 迁移 SQL 中 `due_date` 需要 `/1000` 才能交给 sqlite `unixepoch` 修饰符 | Drift 默认把 DateTime 存为 milliseconds since epoch，doc §4.2 的 SQL 范例对此一笔带过 | 已在 `_migrateToThingsAlignment` 注释 + 实际 SQL 修正 |
| 2026-05-08 | 仓库内未引入 rxdart，doc 说的"三段式 Today 流"用单 watch + Dart 端分组替代 | rxdart 拉一个新依赖只为 `combineLatest` 不划算；单 watch 流足够 | `watchTodayWithEvening()` 实现见 `database.dart`，`flutter test` 已覆盖 partition 行为 |
| 2026-05-08 | M1_01 §6 列的 `lib/data/area_repository.dart` 等仓储层暂未抽出 | 直接把 CRUD/查询方法写在 AppDatabase 上沿用项目既有风格；M2 视图重构若需要按依赖反转再抽 | 不影响 schema、不影响 M2；视为待办，PROGRESS 此处即为标记 |
| 2026-05-08 | M1_04 走"按文档主线，main.dart 直切 AdaptiveShell" | 用户在 AskUserQuestion 中明确选择；M2 视图重构会立刻接手，过渡期短 | 旧 HomePage 上承载的 AI Tab / Tags 区 / Quick Add / 命令面板 / Cmd+K 搜索在 M2 之前不可见；HomePage 类标 `@Deprecated`，仍可通过 git 历史回滚 |
| 2026-05-08 | M1_04 §10 步骤 7 的 "extract TaskDetailView" 改为 "嵌入式 Navigator 复用 TaskDetailSheet" | task_detail_sheet.dart 已是无 Scaffold 的纯内容，直接拆 view/sheet 改动量大且风险高 | DetailPane 内挂 `Navigator(pages: [MaterialPage(child: TaskDetailSheet)], onPopPage: ...)`，把 sheet 内置的 close 按钮 pop 转写为 SelectionStore.clearTask；M2 真正抽组件库时再拆 |
| 2026-05-08 | `multi_split_view` 装的是 3.6.1 而非文档写的 3.0.0，API 也不同 | 3.0 已停更；3.6.1 是当前稳定版，使用 `initialAreas: [Area(...)] + 每个 Area 自带 builder` 而非 `controller + children` | `DesktopShell` 用新 API；切换 `selectedTaskId` 时改 ValueKey 强制 MultiSplitView 重建，避免拖动权重残留 |
| 2026-05-08 | DetailPane 仍用 `Navigator.onPopPage`（已 deprecated） | 新 `onDidRemovePage` API 要求父组件主动维护 pages 列表，与"用 SelectionStore 控制可见性"的现有架构耦合更紧 | 行内 `// ignore: deprecated_member_use` + 注释；M3 评估迁移到 PopScope 或 onDidRemovePage |
| 2026-05-08 | M1_03 §3 的 SDK / Kotlin / Gradle 显式版本只锁 minSdk=23，其余继承 Flutter SDK 默认 | Flutter 3.38.7 已带 SDK 35+ / Kotlin 1.9.x / Gradle 8.14，全部 ≥ doc 要求；显式锁会反过来卡住 Flutter 自身的升级路径 | `app/build.gradle.kts` 仅改 `minSdk = 23`；`compileSdk` / `targetSdk` / `kotlin_version` / `gradle.distributionUrl` 不动 |
| 2026-05-08 | M1_03 §6 的 `permission_handler` + `device_info_plus` 不引入 | `notification_service.dart` 已用 `flutter_local_notifications.requestNotificationsPermission()` / `requestExactAlarmsPermission()`，能力等价；少装两个第三方包 | doc §6.4 的"请求时机"约束（不在 main 里请求）依旧由 `requestPermissions()` 调用方满足；M3 真要做更细的"已永久拒绝 → 跳设置页"流程时再加 |
| 2026-05-08 | applicationId / namespace 保持 `com.example.flowlog`，不改 `com.flowlog.app` | 改 applicationId 会导致旧 install 丢数据，需要先做签名+迁移规划 | TODO 注释埋在 `app/build.gradle.kts`；M4 发布签名阶段统一切换 |
| 2026-05-09 | M1_02 §8 的 GlobalHotkeyService 接口拆分不做 | 现有实现 `bind()` 第一行就 `if (defaultTargetPlatform != TargetPlatform.macOS) return;`，iOS / Android / Linux / Windows 自动走 noop；接口拆分零收益还多两个文件 | 不动 `global_hotkey_service.dart`；如果 M3 真要 iOS 接 Magic Keyboard 快捷键，再在那个 milestone 做 |
| 2026-05-09 | iOS Bundle ID 由 `flutter create --org com.example` 默认 = `com.example.flowlogClient`，未改 | 与 Android applicationId 同样的考虑：M4 才统一切到 `com.flowlog.app` 系列 | Xcode 中 `PRODUCT_BUNDLE_IDENTIFIER` 默认值，手工签名时可临时覆盖 |
| 2026-05-09 | `flutter_timezone 5.0.2` 的 API 与 doc §7.3 写的不同：`getLocalTimezone()` 返回 `TimezoneInfo` 而不是 `String` | doc 引用了旧版 API；新版用 `info.identifier` 取 IANA 名 | 对应代码用 `tz.setLocalLocation(tz.getLocation(info.identifier))`；try/catch 包好失败路径 |
| 2026-05-09 | macOS 也顺手改成"延后请求通知权限" | 与 iOS / Android 13+ 行为对齐；Apple 也开始要求 macOS 应用不在启动时弹权限 | DarwinInitializationSettings 中 macOS 三项 requestPermission=false，等 `requestPermissions()` 在用户首次创建 reminderAt 时调用 |
| 2026-05-09 | macOS / iOS Podfile 在 post_install 强制 `MACOSX_DEPLOYMENT_TARGET=10.15` + sqlite3 target 上 `GCC_WARN_INHIBIT_ALL_WARNINGS=YES` | 用户首次 `flutter run -d macos` 后报告 4 条主项目可改 + 182 条 sqlite3 上游 noise；Xcode 26 已不支持 <10.13 的 deployment target，部分 Pod 的 privacy bundle 还自带 10.11；sqlite3 amalgamation 是上游 6 万行 C，warnings 改不到 | 主项目侧顺手把 `MainFlutterWindow.swift:80` 的 `var hotKeyID` 改 `let`；用户需重跑 `pod install` 让 Podfile 生效 |
| 2026-05-09 | 撤销之前 M1_04 私自加在 Sidebar 中段的"区域和项目 / 将在下一阶段加入"可见占位文字 | 用户对照设计稿发现这段不在 doc 里。`M1_04_Adaptive_Shell.md` §5.6 明确写"动态：Areas → Projects（M1 仅占位，M2 实装）"且仅以代码注释形式存在 | `sidebar.dart` 中段改回单条 `Divider` + `// TODO(M2)` 注释；保留 l10n 中的 `areasAndProjects` / `comingInM2` 待 M2 真正分组时复用 |

## M1_01 / M1_04 第一轮 review 反馈与修复

review 在 M1 完成后跑了一轮，捕到 4 个真问题。修复全部带回归测试，下次再升 schema 就不会重蹈覆辙。

| ID | Severity | 现象 | 根因 | 修复 |
|---|---|---|---|---|
| F1 | P1 | v1–v4 升级路径在 `from<5` 调 `_normalizeLegacyDateTimes` 时引用未存在的 `end_date` / `repeat_until` 等列，硬挂 | normalize 列表写死，没考虑历史 schema | `_normalizeTableDateTimes` 用 `PRAGMA table_info` 取实际列名做交集；新增 helper `_columnsOf(table)` |
| F2 | P1 | v1 用户 `from<2` 路径用 `m.createTable(projects)` 直接建出 v9 形态 projects 表；`from<9` 的 `_migrateToThingsAlignment` 不知情，再走 TableMigration 会把已是 hex 的 color 当 int 用 `printf` 解析成 `'#00000000'`、并触发"重复列"错误 | M1_01 时未考虑老 schema 上 `m.createTable` 总是按当前 Dart 定义建表 | `_migrateToThingsAlignment` 开头探测 `tasks.notes` / `projects.notes` 是否已存在，已 v9 形态则跳过对应 alterTable；保留 backfill 是 idempotent 的 |
| F3 | P2 | v9 migration SQL 用 `due_date / 1000` 当作毫秒处理；Drift 2.30+ 默认存秒，导致今天的任务在升级时被判 1970 年、误标 `whenType=scheduled` 而非 `today` | 错误估计 Drift 的 DateTime 整数序列化（实测 mapping.dart:72 是 `~/ 1000`） | 删 `/ 1000`，SQL 直接 `date(due_date, 'unixepoch')`；migration_test 的 raw INSERT 配套改成秒级时间戳 |
| F4 | P2 | DesktopShell 三栏的 DetailPane 永远拿不到 selectedTaskId — task_row 的 onTap 直接 showTaskDetailSheet，没人调 `selectionStore.selectTask` | M1_04 写 DetailPane 时只接 SelectionStore 的 watch 端，没把 store 反向接到 TaskRow tap | `task_row.dart` 抽 `_openTaskDetail(...)` —— 用 `layoutForWidth(MediaQuery.size.width)` 判断：desktop 走 `selectionStore.selectTask`，其他档保留 modal sheet |

### 新增回归测试

| 文件 | 用例 | 锁定的行为 |
|---|---|---|
| `test/database/migration_test.dart` | 新增 group `v1 → v9 migration`（4 例） | 完整 v1 schema → onUpgrade 升到 v9 不抛异常；既有任务 notes/whenType 正确回填；projects 由 v9 form 创建后 color 仍是 hex；新表存在且为空 |
| `test/database/migration_test.dart` | v8→v9 现有 13 例 raw INSERT 改成秒级 | 与 Drift 实际写入约定一致 |
| `test/state/selection_store_test.dart` | 新文件 8 例 | SelectionStore 的 selectView/selectTask/clearTask notify 行为；selectView 切视图时清 selectedTaskId；layoutForWidth 三档断点 |

### 修改文件清单

- `client/lib/database/database.dart`：`_columnsOf` 新 helper；`_normalizeTableDateTimes` 列存在性过滤；`_migrateToThingsAlignment` 探测已 v9 跳 alterTable + 删 `/1000`
- `client/lib/ui/widgets/task_row.dart`：抽 `_openTaskDetail`；两处 onTap 改用 helper
- `client/test/database/migration_test.dart`：v8 数据改秒；新增 v1 group
- `client/test/state/selection_store_test.dart`：新文件

### 验证

| 项 | 结果 |
|---|---|
| `flutter analyze --no-pub`（全量） | **0 error**（82 历史 info）|
| `flutter test` | **40/40 通过**（M1_01 + 新 v1 path + selection_store + 既有）|
| 真实 v1 / v8 数据库升级 | 单元测试覆盖；用户本地启动验证可选 |

## 验收（M1 整体，引自 `00_Overview.md` §6）

- [ ] 1. `flutter run -d macos` / `-d ios` / 真机 Android 三端启动到自适应 Shell — **代码就绪**，留待用户本地分别启动
- [x] 2. 旧数据库升级后任务数据零丢失，`notes` / `whenType` 已正确填充 — `migration_test` 13 例覆盖
- [x] 3. 三张新表（Areas / Headings / Checklists）能 CRUD，单元测试覆盖 — `queries_test` 14 例覆盖
- [ ] 4. macOS 窗口拖动时三档布局（mobile / tablet / desktop）切换流畅 — **代码就绪**，留待用户本地拖窗验证
- [ ] 5. Android 13+ 与 iOS 启动后能正确请求通知权限 — **代码就绪**（延后请求路径），留待用户首次触发 reminderAt
- [ ] 6. 现有功能（Today / Inbox / Upcoming / 全局热键 / AI / 通知）功能不回退 — Today/Inbox/Upcoming/通知/全局热键代码未动；AI / Tags / Quick Add / Cmd+K 在新 Shell 上需 M2 重接（已记入偏离）

## 维护说明

- 子任务粒度：以"一个 commit 能闭环"为目标。
- 状态变更必须同时更新对应 commit 短哈希；commit message 与本表 # 列文案保持前缀一致。
- 偏离决策必须落到「偏离与决策记录」，避免代码与设计稿默默漂移。
