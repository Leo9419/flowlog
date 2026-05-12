import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'appTitle': 'FlowLog',
      'today': '今天',
      'inbox': '任务箱',
      'allTasks': '全部',
      'upcoming': '即将到期',
      'calendar': '日历',
      'profile': '我的',
      'addTask': '添加任务',
      'addTaskToToday': '添加任务到 \"今天\"',
      'todayEmpty': '今天没有任务，享受生活吧！',
      'allEmpty': '暂无任务',
      'upcomingEmpty': '暂无即将到期任务',
      'todayLabel': '今天',
      'inboxTaskTitle': '收集箱任务',
      'noDueDate': '未设置开始时间',
      'noEndDate': '未设置结束时间',
      'calendarDayTasks': '当天 {count} 个任务',
      'profileUserName': 'FlowLog 用户',
      'profileTapToLogin': '点击登录或同步',
      'settings': '设置',
      'appearance': '主题和外观',
      'notifications': '提醒和通知',
      'themeLight': '浅色模式',
      'themeDark': '深色模式',
      'language': '语言',
      'languageChinese': '简体中文',
      'languageEnglish': 'English',
      'searchTasks': '搜索任务',
      'searchHint': '输入关键字搜索任务',
      'searchEmpty': '没有匹配的任务',
      'commandPaletteComingSoon': '命令面板即将推出',
      'trash': '回收站',
      'trashEmpty': '回收站为空',
      'restore': '恢复',
      'notificationsEnabled': '启用通知',
      'notificationsPermissionDenied': '需要在系统设置中允许通知权限',
      'testNotification': '发送测试提醒',
      'testNotificationSent': '已发送测试提醒',
      'tasksCount': '共 {count} 个任务',
      'upcomingReminder': '即将到期提醒',
      'upcomingSummaryTitle': '每日 17:00 汇总提醒',
      'upcomingSummarySubtitle': '汇总未来 24 小时内任务',
      'upcomingBeforeDueTitle': '到期前 30 分钟提醒',
      'upcomingBeforeDueSubtitle': '单个任务提醒',
      'testNotificationTitle': '提醒测试',
      'testNotificationBody': '如果你看到这条提醒，说明配置正常',
      'upcomingSummaryNotificationTitle': '即将到期汇总',
      'upcomingSummaryNotificationBody': '未来 24 小时有 {count} 个任务到期',
      'upcomingSummaryNotificationEmpty': '未来 24 小时暂无到期任务',
      'dueSoonNotificationTitle': '任务即将到期',
      'dueSoonNotificationBody': '{title} 将在 30 分钟后到期',
      'allDay': '全天',
      'dueTime': '开始时间',
      'endTime': '结束时间',
      'dailyReminder': '每日提醒',
      'reminderTime': '提醒时间',
      'reminderSound': '提醒声音',
      'sortByCreated': '按创建时间排序',
      'sortByDueDate': '按开始时间排序',
      'sortByPriority': '按优先级排序',
      'projectEmpty': '暂无任务',
      'manageProjects': '清单管理',
      'manageTags': '标签管理',
      'addProject': '新建清单',
      'renameProject': '重命名清单',
      'addTag': '新建标签',
      'renameTag': '重命名标签',
      'projectListEmpty': '暂无清单',
      'tagListEmpty': '暂无标签',
      'add': '添加',
      'save': '保存',
      'cancel': '取消',
      'delete': '删除',
      'changeColor': '更换颜色',
      'taskDetails': '任务详情',
      'taskTitle': '任务标题',
      'titleRequired': '请输入任务标题',
      'project': '清单',
      'dueDate': '开始日期',
      'endDate': '结束日期',
      'repeat': '重复',
      'repeatNone': '不重复',
      'repeatDaily': '每天',
      'repeatWeekly': '每周',
      'repeatMonthly': '每月',
      'repeatYearly': '每年',
      'repeatCustom': '自定义',
      'repeatEditScopeTitle': '应用更改到',
      'repeatEditScopeThis': '仅本次',
      'repeatEditScopeThisAndFuture': '本次及之后',
      'repeatEditScopeAll': '全部',
      'repeatScopeAppliedThis': '已应用到本次',
      'repeatScopeAppliedThisAndFuture': '已应用到本次及之后',
      'repeatScopeAppliedAll': '已应用到全部',
      'overdue': '逾期',
      'completed': '已完成',
      'shortcuts': '快捷键',
      'shortcutsHint': '当前仅支持 macOS，可设置全局快捷键',
      'aiSettings': 'AI 设置',
      'aiSettingsHint': '可选择本地模型或云端模型，云端支持 OpenAI 兼容接口',
      'aiProvider': '模型来源',
      'aiProviderLocal': '本地模型',
      'aiProviderLocalHint': '使用本机 Ollama 服务',
      'aiProviderCloud': '云端模型',
      'aiProviderCloudHint': '使用厂商 API（OpenAI 兼容）',
      'aiProviderClaudeCode': 'Claude Code',
      'aiProviderClaudeCodeHint': '直接调用本机 claude CLI',
      'aiCloudSettings': '云端配置',
      'aiCloudEndpoint': '云端服务地址',
      'aiCloudEndpointHint': '如 https://api.openai.com',
      'aiCloudApiKey': 'API Key',
      'aiCloudApiKeyHint': '输入厂商 API Key',
      'aiCloudModel': '云端模型',
      'aiCloudModelHint': '如 gpt-4o-mini',
      'aiCloudTest': '测试云端模型',
      'aiCloudTesting': '正在测试...',
      'aiCloudTestSuccess': '云端模型已就绪',
      'aiCloudTestFailed': '无法连接云端 AI 服务',
      'aiCloudTestFailedWithReason': '云端测试失败：{reason}',
      'aiProviderFootnote': 'Ollama、云端或 Claude Code 均可用于 AI 能力',
      'aiClaudeSettings': 'Claude Code 配置',
      'aiClaudeCommand': 'Claude 命令',
      'aiClaudeCommandHint': '默认 claude，可填写完整路径',
      'aiClaudeTest': '测试 Claude Code',
      'aiClaudeTesting': '正在测试...',
      'aiClaudeTestSuccess': 'Claude Code 已就绪',
      'aiClaudeTestFailed': '无法调用 Claude Code',
      'aiLocalSettings': '本地配置',
      'aiLocalEndpoint': '本地服务地址',
      'aiLocalEndpointHint': '默认 http://localhost:11434',
      'aiLocalModel': '本地模型',
      'aiLocalModelHint': '选择或输入模型名，如 llama3:latest',
      'aiLocalTest': '测试本地模型',
      'aiLocalTesting': '正在测试...',
      'aiLocalTestSuccess': '本地模型已就绪',
      'aiLocalTestModelMissing': '未找到模型 {model}，请先执行 ollama pull {model}',
      'aiLocalTestFailed': '无法连接本地 AI 服务',
      'aiQuickAdd': 'AI 解析',
      'aiQuickAddParsing': '解析中...',
      'aiQuickAddPreview': 'AI 预览',
      'aiQuickAddFailed': 'AI 解析失败',
      'aiQuickAddFailedWithReason': 'AI 解析失败：{reason}',
      'aiQuickAddNoInput': '请先输入任务内容',
      'aiCloudUnavailable': '云端 AI 暂未接入',
      'aiLocalConfigMissing': '请先设置本地服务地址和模型',
      'aiCloudConfigMissing': '请先设置云端地址、API Key 和模型',
      'aiClaudeConfigMissing': '请先设置 Claude 命令',
      'aiLocalEndpointMissing': '请先设置本地服务地址',
      'aiLocalModelsTitle': '本地模型列表',
      'aiLocalModelsRefresh': '刷新',
      'aiLocalModelsLoading': '正在加载模型列表...',
      'aiLocalModelsEmpty': '未检测到本地模型',
      'aiLocalModelsFailed': '读取模型列表失败',
      'errorDetails': '错误详情',
      'copy': '复制',
      'copied': '已复制',
      'aiWeeklyReport': 'AI 周报',
      'aiWeeklyReportHint': '基于 AI 自动生成周报',
      'aiWeeklyReportGenerate': '生成周报',
      'aiWeeklyReportLoading': '生成中...',
      'aiWeeklyReportSummaryTitle': '周报摘要',
      'aiWeeklyReportRegenerate': '重新生成',
      'aiWeeklyReportNoTasks': '本周没有任务',
      'aiWeeklyReportFailed': '周报生成失败',
      'aiWeeklyReportThisWeek': '本周',
      'onboardingWelcomeTitle': '欢迎使用 FlowLog',
      'onboardingWelcomeBody': '用清单和标签整理任务，今天/即将到期/日历一目了然。',
      'onboardingQuickAddTitle': '快速添加任务',
      'onboardingQuickAddBody': '支持 Cmd+N 快速添加，还可用 AI 自动解析时间与标签。',
      'onboardingOrganizeTitle': '清单与标签',
      'onboardingOrganizeBody': '清单用于项目分类，标签用于跨清单筛选。',
      'onboardingInsightsTitle': '提醒与周报',
      'onboardingInsightsBody': '每日 17:00 汇总提醒，到期前 30 分钟提醒，AI 周报自动总结。',
      'onboardingSkip': '跳过',
      'onboardingNext': '下一步',
      'onboardingStart': '开始使用',
      'aiChat': '智能助手',
      'aiChatHint': '问问你的任务与计划',
      'aiChatEmpty': '开始使用智能助手吧',
      'aiChatInputHint': '输入问题，例如：今天有哪些任务？',
      'aiChatSend': '发送',
      'aiChatLoading': '智能助手正在思考...',
      'aiChatNoTasksToday': '今天没有任务',
      'aiChatReportWeekly': '生成周报',
      'aiChatReportMonthly': '生成月报',
      'aiChatReportYearly': '生成年报',
      'aiChatReportFailed': '报告生成失败',
      'aiImageAdd': '图片解析',
      'aiImagePicking': '读取图片...',
      'aiImageNoImage': '未选择图片',
      'aiImageInvalid': '无法读取图片',
      'aiImageParseFailed': '图片解析失败',
      'aiImageCloudOnly': '图片解析需要云端模型',
      'dailyReportReminder': '日报提醒',
      'dailyReportTime': '日报时间',
      'weeklyReportReminder': '周报提醒',
      'weeklyReportTime': '周报时间',
      'weeklyReportDay': '周报日期',
      'dueAtReminder': '到期时提醒',
      'dueAtReminderSubtitle': '任务到期时推送提醒',
      'dailyReportNotificationTitle': '日报提醒',
      'dailyReportNotificationBody': '今日待办 {due}，已完成 {done}，逾期 {overdue}',
      'weeklyReportNotificationTitle': '周报提醒',
      'weeklyReportNotificationBody':
          '本周已完成 {done}，新增 {created}，到期 {due}，未完成 {open}',
      'dueNowNotificationTitle': '任务到期',
      'dueNowNotificationBody': '{title} 已到期',
      'created': '新增',
      'dueThisWeek': '本周到期',
      'shortcutsGlobal': '全局快捷键',
      'shortcutsAdd': '快速添加',
      'shortcutsNavigation': '切换视图',
      'shortcutsSearch': '搜索与动作',
      'shortcutsGeneral': '通用',
      'globalHotkeyEnabled': '启用全局快捷键',
      'globalHotkeyHint': '可在任何应用内唤出快速添加',
      'globalHotkeyQuickAdd': '全局快速添加',
      'shortcutRecorderTitle': '录制快捷键',
      'shortcutRecorderHint': '按下新的组合键',
      'shortcutRecorderInvalid': '请至少包含一个修饰键',
      'shortcutRecorderUnsupported': '仅支持字母、数字或空格键',
      'shortcutQuickAdd': '快速添加（当前视图）',
      'shortcutQuickAddInbox': '快速添加到任务箱',
      'shortcutQuickAddToday': '快速添加到今天',
      'shortcutSearch': '搜索任务',
      'shortcutCommandPalette': '命令面板（预留）',
      'shortcutToday': '打开 今天',
      'shortcutInbox': '打开 任务箱',
      'shortcutUpcoming': '打开 即将到期',
      'shortcutCalendar': '打开 日历',
      'shortcutClose': '关闭弹窗/详情',
      'clear': '清除',
      'edit': '编辑',
      'priority': '优先级',
      'priorityNone': '无',
      'priorityLow': '低',
      'priorityMedium': '中',
      'priorityHigh': '高',
      'unknownProject': '未知清单',
      'lists': '清单',
      'tags': '标签',
      'subtasks': '子任务',
      'subtasksEmpty': '暂无子任务',
      'addSubtask': '添加子任务',
      'subtaskProgress': '{done}/{total} 已完成',
      'parentTask': '父任务',
      'parentTaskMissing': '父任务已删除',
      'subtaskNoNested': '子任务不支持再添加子任务',
      'noTags': '暂无标签',
      'editTags': '编辑标签',
      'selectTags': '选择标签',
      'tagEmpty': '该标签暂无任务',
      // M1_04 Shell —— Things 对齐的视图与占位文案
      'anytime': '随时',
      'someday': '将来',
      'logbook': '日志',
      'areasAndProjects': '区域和项目',
      'comingInM2': '将在下一阶段加入',
      'selectTaskToSeeDetails': '选择一个任务查看详情',
      'anytimeEmpty': '暂无随时任务',
      'somedayEmpty': '暂无未来任务',
      'logbookEmpty': '已完成的任务会汇总在这里',
      'projectNotFound': '项目不存在或已被删除',
      'tagNotFound': '标签不存在或已被删除',
      'selectAProject': '请选择一个项目',
      'selectATag': '请选择一个标签',
      'searchComingInM2': '搜索 — 将在下一阶段加入',
      // Quick Find（Things 3 风格的命令面板）
      'quickFind': '快速查找',
      'quickFindRecent': '最近',
      'quickFindHint': '快速切换列表、查找待办事项、搜索标签…',
    },
    'en': {
      'appTitle': 'FlowLog',
      'today': 'Today',
      'inbox': 'Inbox',
      'allTasks': 'All',
      'upcoming': 'Upcoming',
      'calendar': 'Calendar',
      'profile': 'Me',
      'addTask': 'Add a task',
      'addTaskToToday': 'Add task to "Today"',
      'todayEmpty': 'No tasks today. Enjoy your time!',
      'allEmpty': 'No tasks yet',
      'upcomingEmpty': 'No upcoming tasks',
      'todayLabel': 'Today',
      'inboxTaskTitle': 'Inbox task',
      'noDueDate': 'No start date',
      'noEndDate': 'No end date',
      'calendarDayTasks': '{count} tasks on this day',
      'profileUserName': 'FlowLog User',
      'profileTapToLogin': 'Tap to sign in or sync',
      'settings': 'Settings',
      'appearance': 'Appearance',
      'notifications': 'Notifications',
      'themeLight': 'Light theme',
      'themeDark': 'Dark theme',
      'language': 'Language',
      'languageChinese': '简体中文',
      'languageEnglish': 'English',
      'searchTasks': 'Search tasks',
      'searchHint': 'Type to search tasks',
      'searchEmpty': 'No matching tasks',
      'commandPaletteComingSoon': 'Command palette coming soon',
      'trash': 'Trash',
      'trashEmpty': 'Trash is empty',
      'restore': 'Restore',
      'notificationsEnabled': 'Enable notifications',
      'notificationsPermissionDenied':
          'Enable notification permissions in System Settings',
      'testNotification': 'Send test notification',
      'testNotificationSent': 'Test notification sent',
      'tasksCount': '{count} tasks',
      'upcomingReminder': 'Upcoming reminders',
      'upcomingSummaryTitle': 'Daily summary at 5:00 PM',
      'upcomingSummarySubtitle': 'Tasks due in the next 24 hours',
      'upcomingBeforeDueTitle': 'Reminder 30 minutes before due',
      'upcomingBeforeDueSubtitle': 'Single-task reminders',
      'testNotificationTitle': 'Notification test',
      'testNotificationBody': 'If you can see this, notifications are working',
      'upcomingSummaryNotificationTitle': 'Upcoming summary',
      'upcomingSummaryNotificationBody':
          '{count} tasks due in the next 24 hours',
      'upcomingSummaryNotificationEmpty': 'No tasks due in the next 24 hours',
      'dueSoonNotificationTitle': 'Task due soon',
      'dueSoonNotificationBody': '{title} is due in 30 minutes',
      'allDay': 'All day',
      'dueTime': 'Start time',
      'endTime': 'End time',
      'dailyReminder': 'Daily reminder',
      'reminderTime': 'Reminder time',
      'reminderSound': 'Reminder sound',
      'sortByCreated': 'Sort by created',
      'sortByDueDate': 'Sort by start date',
      'sortByPriority': 'Sort by priority',
      'projectEmpty': 'No tasks yet',
      'manageProjects': 'Manage lists',
      'manageTags': 'Manage tags',
      'addProject': 'New list',
      'renameProject': 'Rename list',
      'addTag': 'New tag',
      'renameTag': 'Rename tag',
      'projectListEmpty': 'No lists yet',
      'tagListEmpty': 'No tags yet',
      'add': 'Add',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'changeColor': 'Change color',
      'taskDetails': 'Task details',
      'taskTitle': 'Task title',
      'titleRequired': 'Please enter a task title',
      'project': 'List',
      'dueDate': 'Start date',
      'endDate': 'End date',
      'repeat': 'Repeat',
      'repeatNone': 'Does not repeat',
      'repeatDaily': 'Daily',
      'repeatWeekly': 'Weekly',
      'repeatMonthly': 'Monthly',
      'repeatYearly': 'Yearly',
      'repeatCustom': 'Custom',
      'repeatEditScopeTitle': 'Apply changes to',
      'repeatEditScopeThis': 'This task',
      'repeatEditScopeThisAndFuture': 'This and future',
      'repeatEditScopeAll': 'All tasks',
      'repeatScopeAppliedThis': 'Applied to this task',
      'repeatScopeAppliedThisAndFuture': 'Applied to this and future',
      'repeatScopeAppliedAll': 'Applied to all tasks',
      'overdue': 'Overdue',
      'completed': 'Completed',
      'shortcuts': 'Shortcuts',
      'shortcutsHint': 'macOS only for now. Global shortcuts are customizable.',
      'aiSettings': 'AI Settings',
      'aiSettingsHint':
          'Choose local or cloud models. Cloud uses OpenAI-compatible APIs.',
      'aiProvider': 'Model provider',
      'aiProviderLocal': 'Local model',
      'aiProviderLocalHint': 'Use Ollama on this Mac',
      'aiProviderCloud': 'Cloud model',
      'aiProviderCloudHint': 'Use vendor API (OpenAI compatible)',
      'aiProviderClaudeCode': 'Claude Code',
      'aiProviderClaudeCodeHint': 'Call the local claude CLI directly',
      'aiCloudSettings': 'Cloud settings',
      'aiCloudEndpoint': 'Cloud endpoint',
      'aiCloudEndpointHint': 'e.g. https://api.openai.com',
      'aiCloudApiKey': 'API key',
      'aiCloudApiKeyHint': 'Paste vendor API key',
      'aiCloudModel': 'Cloud model',
      'aiCloudModelHint': 'e.g. gpt-4o-mini',
      'aiCloudTest': 'Test cloud model',
      'aiCloudTesting': 'Testing...',
      'aiCloudTestSuccess': 'Cloud model is ready',
      'aiCloudTestFailed': 'Could not reach cloud AI service',
      'aiCloudTestFailedWithReason': 'Cloud test failed: {reason}',
      'aiProviderFootnote':
          'Ollama, cloud, or Claude Code can power AI features.',
      'aiClaudeSettings': 'Claude Code settings',
      'aiClaudeCommand': 'Claude command',
      'aiClaudeCommandHint': 'Default: claude. Full path is supported.',
      'aiClaudeTest': 'Test Claude Code',
      'aiClaudeTesting': 'Testing...',
      'aiClaudeTestSuccess': 'Claude Code is ready',
      'aiClaudeTestFailed': 'Could not run Claude Code',
      'aiLocalSettings': 'Local settings',
      'aiLocalEndpoint': 'Local endpoint',
      'aiLocalEndpointHint': 'Default http://localhost:11434',
      'aiLocalModel': 'Local model',
      'aiLocalModelHint': 'Select or enter model name, e.g. llama3:latest',
      'aiLocalTest': 'Test local model',
      'aiLocalTesting': 'Testing...',
      'aiLocalTestSuccess': 'Local model is ready',
      'aiLocalTestModelMissing':
          'Model {model} not found. Run: ollama pull {model}',
      'aiLocalTestFailed': 'Could not reach local AI service',
      'aiQuickAdd': 'AI parse',
      'aiQuickAddParsing': 'Parsing...',
      'aiQuickAddPreview': 'AI preview',
      'aiQuickAddFailed': 'AI parse failed',
      'aiQuickAddFailedWithReason': 'AI parse failed: {reason}',
      'aiQuickAddNoInput': 'Enter a task first',
      'aiCloudUnavailable': 'Cloud AI is not available yet',
      'aiLocalConfigMissing': 'Set local endpoint and model first',
      'aiCloudConfigMissing': 'Set cloud endpoint, API key, and model first',
      'aiClaudeConfigMissing': 'Set Claude command first',
      'aiLocalEndpointMissing': 'Set local endpoint first',
      'aiLocalModelsTitle': 'Local models',
      'aiLocalModelsRefresh': 'Refresh',
      'aiLocalModelsLoading': 'Loading model list...',
      'aiLocalModelsEmpty': 'No local models detected',
      'aiLocalModelsFailed': 'Failed to load model list',
      'errorDetails': 'Error details',
      'copy': 'Copy',
      'copied': 'Copied',
      'aiWeeklyReport': 'AI Weekly Report',
      'aiWeeklyReportHint': 'Generate a weekly report with AI',
      'aiWeeklyReportGenerate': 'Generate report',
      'aiWeeklyReportLoading': 'Generating...',
      'aiWeeklyReportSummaryTitle': 'Weekly Summary',
      'aiWeeklyReportRegenerate': 'Regenerate',
      'aiWeeklyReportNoTasks': 'No tasks this week',
      'aiWeeklyReportFailed': 'Failed to generate weekly report',
      'aiWeeklyReportThisWeek': 'This week',
      'onboardingWelcomeTitle': 'Welcome to FlowLog',
      'onboardingWelcomeBody':
          'Organize tasks with lists and tags. Today, Upcoming, and Calendar keep you on track.',
      'onboardingQuickAddTitle': 'Quick Add',
      'onboardingQuickAddBody':
          'Use Cmd+N to add tasks fast. AI can parse time and tags.',
      'onboardingOrganizeTitle': 'Lists & Tags',
      'onboardingOrganizeBody':
          'Lists group projects, tags filter across lists.',
      'onboardingInsightsTitle': 'Reminders & Weekly Report',
      'onboardingInsightsBody':
          'Daily 5 PM summary, 30-minute reminders, and AI weekly report.',
      'onboardingSkip': 'Skip',
      'onboardingNext': 'Next',
      'onboardingStart': 'Get Started',
      'aiChat': 'Smart Assistant',
      'aiChatHint': 'Ask about your tasks and plans',
      'aiChatEmpty': 'Start using the assistant',
      'aiChatInputHint': 'Ask a question, e.g. what is due today?',
      'aiChatSend': 'Send',
      'aiChatLoading': 'Assistant is thinking...',
      'aiChatNoTasksToday': 'No tasks due today',
      'aiChatReportWeekly': 'Generate weekly report',
      'aiChatReportMonthly': 'Generate monthly report',
      'aiChatReportYearly': 'Generate yearly report',
      'aiChatReportFailed': 'Failed to generate report',
      'aiImageAdd': 'Image Parse',
      'aiImagePicking': 'Loading image...',
      'aiImageNoImage': 'No image selected',
      'aiImageInvalid': 'Unable to read image',
      'aiImageParseFailed': 'Image parse failed',
      'aiImageCloudOnly': 'Image parsing requires a cloud model',
      'dailyReportReminder': 'Daily report',
      'dailyReportTime': 'Daily report time',
      'weeklyReportReminder': 'Weekly report',
      'weeklyReportTime': 'Weekly report time',
      'weeklyReportDay': 'Weekly report day',
      'dueAtReminder': 'Due time reminder',
      'dueAtReminderSubtitle': 'Notify when a task reaches its due time',
      'dailyReportNotificationTitle': 'Daily report',
      'dailyReportNotificationBody':
          'Due {due}, done {done}, overdue {overdue}',
      'weeklyReportNotificationTitle': 'Weekly report',
      'weeklyReportNotificationBody':
          'Done {done}, created {created}, due {due}, open {open}',
      'dueNowNotificationTitle': 'Task due',
      'dueNowNotificationBody': '{title} is due',
      'created': 'Created',
      'dueThisWeek': 'Due this week',
      'shortcutsGlobal': 'Global shortcuts',
      'shortcutsAdd': 'Quick Add',
      'shortcutsNavigation': 'Navigation',
      'shortcutsSearch': 'Search and Actions',
      'shortcutsGeneral': 'General',
      'globalHotkeyEnabled': 'Enable global hotkeys',
      'globalHotkeyHint': 'Trigger quick add from any app',
      'globalHotkeyQuickAdd': 'Global quick add',
      'shortcutRecorderTitle': 'Record shortcut',
      'shortcutRecorderHint': 'Press a new key combination',
      'shortcutRecorderInvalid': 'Use at least one modifier key',
      'shortcutRecorderUnsupported': 'Letters, digits, and Space only',
      'shortcutQuickAdd': 'Quick add (current view)',
      'shortcutQuickAddInbox': 'Quick add to Inbox',
      'shortcutQuickAddToday': 'Quick add to Today',
      'shortcutSearch': 'Search tasks',
      'shortcutCommandPalette': 'Command palette (coming soon)',
      'shortcutToday': 'Go to Today',
      'shortcutInbox': 'Go to Inbox',
      'shortcutUpcoming': 'Go to Upcoming',
      'shortcutCalendar': 'Go to Calendar',
      'shortcutClose': 'Close dialog/details',
      'clear': 'Clear',
      'edit': 'Edit',
      'priority': 'Priority',
      'priorityNone': 'None',
      'priorityLow': 'Low',
      'priorityMedium': 'Medium',
      'priorityHigh': 'High',
      'unknownProject': 'Unknown list',
      'lists': 'Lists',
      'tags': 'Tags',
      'subtasks': 'Subtasks',
      'subtasksEmpty': 'No subtasks',
      'addSubtask': 'Add subtask',
      'subtaskProgress': '{done}/{total} completed',
      'parentTask': 'Parent task',
      'parentTaskMissing': 'Parent task not found',
      'subtaskNoNested': 'Subtasks cannot have subtasks',
      'noTags': 'No tags',
      'editTags': 'Edit tags',
      'selectTags': 'Select tags',
      'tagEmpty': 'No tasks with this tag',
      // M1_04 Shell — Things-aligned views & placeholder copy
      'anytime': 'Anytime',
      'someday': 'Future',
      'logbook': 'Logbook',
      'areasAndProjects': 'Areas & Projects',
      'comingInM2': 'Coming in M2',
      'selectTaskToSeeDetails': 'Select a task to see details',
      'anytimeEmpty': 'No anytime tasks yet.',
      'somedayEmpty': 'No tasks scheduled for later.',
      'logbookEmpty': 'Completed tasks land here.',
      'projectNotFound': 'Project not found',
      'tagNotFound': 'Tag not found',
      'selectAProject': 'Select a project',
      'selectATag': 'Select a tag',
      'searchComingInM2': 'Search — coming in M2',
      // Quick Find (Things 3-style command palette)
      'quickFind': 'Quick Find',
      'quickFindRecent': 'Recent',
      'quickFindHint': 'Quickly switch lists, find tasks, search tags…',
    },
  };

  String _text(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  String get appTitle => _text('appTitle');
  String get today => _text('today');
  String get inbox => _text('inbox');
  String get allTasks => _text('allTasks');
  String get upcoming => _text('upcoming');
  // M1_04 Shell
  String get anytime => _text('anytime');
  String get someday => _text('someday');
  String get logbook => _text('logbook');
  String get areasAndProjects => _text('areasAndProjects');
  String get comingInM2 => _text('comingInM2');
  String get selectTaskToSeeDetails => _text('selectTaskToSeeDetails');
  String get anytimeEmpty => _text('anytimeEmpty');
  String get somedayEmpty => _text('somedayEmpty');
  String get logbookEmpty => _text('logbookEmpty');
  String get projectNotFound => _text('projectNotFound');
  String get tagNotFound => _text('tagNotFound');
  String get selectAProject => _text('selectAProject');
  String get selectATag => _text('selectATag');
  String get searchComingInM2 => _text('searchComingInM2');
  String get quickFind => _text('quickFind');
  String get quickFindRecent => _text('quickFindRecent');
  String get quickFindHint => _text('quickFindHint');
  String get calendar => _text('calendar');
  String get profile => _text('profile');
  String get addTask => _text('addTask');
  String get addTaskToToday => _text('addTaskToToday');
  String get todayEmpty => _text('todayEmpty');
  String get allEmpty => _text('allEmpty');
  String get upcomingEmpty => _text('upcomingEmpty');
  String get todayLabel => _text('todayLabel');
  String get inboxTaskTitle => _text('inboxTaskTitle');
  String get noDueDate => _text('noDueDate');
  String get noEndDate => _text('noEndDate');
  String get profileUserName => _text('profileUserName');
  String get profileTapToLogin => _text('profileTapToLogin');
  String get settings => _text('settings');
  String get appearance => _text('appearance');
  String get notifications => _text('notifications');
  String get themeLight => _text('themeLight');
  String get themeDark => _text('themeDark');
  String get language => _text('language');
  String get languageChinese => _text('languageChinese');
  String get languageEnglish => _text('languageEnglish');
  String get searchTasks => _text('searchTasks');
  String get searchHint => _text('searchHint');
  String get searchEmpty => _text('searchEmpty');
  String get commandPaletteComingSoon => _text('commandPaletteComingSoon');
  String get trash => _text('trash');
  String get trashEmpty => _text('trashEmpty');
  String get restore => _text('restore');
  String get notificationsEnabled => _text('notificationsEnabled');
  String get notificationsPermissionDenied =>
      _text('notificationsPermissionDenied');
  String get testNotification => _text('testNotification');
  String get testNotificationSent => _text('testNotificationSent');
  String get upcomingReminder => _text('upcomingReminder');
  String get upcomingSummaryTitle => _text('upcomingSummaryTitle');
  String get upcomingSummarySubtitle => _text('upcomingSummarySubtitle');
  String get upcomingBeforeDueTitle => _text('upcomingBeforeDueTitle');
  String get upcomingBeforeDueSubtitle => _text('upcomingBeforeDueSubtitle');
  String get testNotificationTitle => _text('testNotificationTitle');
  String get testNotificationBody => _text('testNotificationBody');
  String get upcomingSummaryNotificationTitle =>
      _text('upcomingSummaryNotificationTitle');
  String get upcomingSummaryNotificationEmpty =>
      _text('upcomingSummaryNotificationEmpty');
  String get dueSoonNotificationTitle => _text('dueSoonNotificationTitle');
  String get allDay => _text('allDay');
  String get dueTime => _text('dueTime');
  String get endTime => _text('endTime');
  String get dailyReminder => _text('dailyReminder');
  String get reminderTime => _text('reminderTime');
  String get reminderSound => _text('reminderSound');
  String get sortByCreated => _text('sortByCreated');
  String get sortByDueDate => _text('sortByDueDate');
  String get sortByPriority => _text('sortByPriority');
  String get projectEmpty => _text('projectEmpty');
  String get manageProjects => _text('manageProjects');
  String get manageTags => _text('manageTags');
  String get addProject => _text('addProject');
  String get renameProject => _text('renameProject');
  String get addTag => _text('addTag');
  String get renameTag => _text('renameTag');
  String get projectListEmpty => _text('projectListEmpty');
  String get tagListEmpty => _text('tagListEmpty');
  String get add => _text('add');
  String get save => _text('save');
  String get cancel => _text('cancel');
  String get delete => _text('delete');
  String get changeColor => _text('changeColor');
  String get taskDetails => _text('taskDetails');
  String get taskTitle => _text('taskTitle');
  String get titleRequired => _text('titleRequired');
  String get project => _text('project');
  String get dueDate => _text('dueDate');
  String get endDate => _text('endDate');
  String get repeat => _text('repeat');
  String get repeatNone => _text('repeatNone');
  String get repeatDaily => _text('repeatDaily');
  String get repeatWeekly => _text('repeatWeekly');
  String get repeatMonthly => _text('repeatMonthly');
  String get repeatYearly => _text('repeatYearly');
  String get repeatCustom => _text('repeatCustom');
  String get repeatEditScopeTitle => _text('repeatEditScopeTitle');
  String get repeatEditScopeThis => _text('repeatEditScopeThis');
  String get repeatEditScopeThisAndFuture =>
      _text('repeatEditScopeThisAndFuture');
  String get repeatEditScopeAll => _text('repeatEditScopeAll');
  String get repeatScopeAppliedThis => _text('repeatScopeAppliedThis');
  String get repeatScopeAppliedThisAndFuture =>
      _text('repeatScopeAppliedThisAndFuture');
  String get repeatScopeAppliedAll => _text('repeatScopeAppliedAll');
  String get overdue => _text('overdue');
  String get completed => _text('completed');
  String get shortcuts => _text('shortcuts');
  String get shortcutsHint => _text('shortcutsHint');
  String get aiSettings => _text('aiSettings');
  String get aiSettingsHint => _text('aiSettingsHint');
  String get aiProvider => _text('aiProvider');
  String get aiProviderLocal => _text('aiProviderLocal');
  String get aiProviderLocalHint => _text('aiProviderLocalHint');
  String get aiProviderCloud => _text('aiProviderCloud');
  String get aiProviderCloudHint => _text('aiProviderCloudHint');
  String get aiProviderClaudeCode => _text('aiProviderClaudeCode');
  String get aiProviderClaudeCodeHint => _text('aiProviderClaudeCodeHint');
  String get aiCloudSettings => _text('aiCloudSettings');
  String get aiCloudEndpoint => _text('aiCloudEndpoint');
  String get aiCloudEndpointHint => _text('aiCloudEndpointHint');
  String get aiCloudApiKey => _text('aiCloudApiKey');
  String get aiCloudApiKeyHint => _text('aiCloudApiKeyHint');
  String get aiCloudModel => _text('aiCloudModel');
  String get aiCloudModelHint => _text('aiCloudModelHint');
  String get aiCloudTest => _text('aiCloudTest');
  String get aiCloudTesting => _text('aiCloudTesting');
  String get aiCloudTestSuccess => _text('aiCloudTestSuccess');
  String get aiCloudTestFailed => _text('aiCloudTestFailed');
  String get aiProviderFootnote => _text('aiProviderFootnote');
  String get aiClaudeSettings => _text('aiClaudeSettings');
  String get aiClaudeCommand => _text('aiClaudeCommand');
  String get aiClaudeCommandHint => _text('aiClaudeCommandHint');
  String get aiClaudeTest => _text('aiClaudeTest');
  String get aiClaudeTesting => _text('aiClaudeTesting');
  String get aiClaudeTestSuccess => _text('aiClaudeTestSuccess');
  String get aiClaudeTestFailed => _text('aiClaudeTestFailed');
  String get aiLocalSettings => _text('aiLocalSettings');
  String get aiLocalEndpoint => _text('aiLocalEndpoint');
  String get aiLocalEndpointHint => _text('aiLocalEndpointHint');
  String get aiLocalModel => _text('aiLocalModel');
  String get aiLocalModelHint => _text('aiLocalModelHint');
  String get aiLocalTest => _text('aiLocalTest');
  String get aiLocalTesting => _text('aiLocalTesting');
  String get aiLocalTestSuccess => _text('aiLocalTestSuccess');
  String get aiLocalTestFailed => _text('aiLocalTestFailed');
  String get aiQuickAdd => _text('aiQuickAdd');
  String get aiQuickAddParsing => _text('aiQuickAddParsing');
  String get aiQuickAddPreview => _text('aiQuickAddPreview');
  String get aiQuickAddFailed => _text('aiQuickAddFailed');
  String get aiQuickAddNoInput => _text('aiQuickAddNoInput');
  String get aiCloudUnavailable => _text('aiCloudUnavailable');
  String get aiLocalConfigMissing => _text('aiLocalConfigMissing');
  String get aiCloudConfigMissing => _text('aiCloudConfigMissing');
  String get aiClaudeConfigMissing => _text('aiClaudeConfigMissing');
  String get aiLocalEndpointMissing => _text('aiLocalEndpointMissing');
  String get aiLocalModelsTitle => _text('aiLocalModelsTitle');
  String get aiLocalModelsRefresh => _text('aiLocalModelsRefresh');
  String get aiLocalModelsLoading => _text('aiLocalModelsLoading');
  String get aiLocalModelsEmpty => _text('aiLocalModelsEmpty');
  String get aiLocalModelsFailed => _text('aiLocalModelsFailed');
  String get errorDetails => _text('errorDetails');
  String get copy => _text('copy');
  String get copied => _text('copied');
  String get aiWeeklyReport => _text('aiWeeklyReport');
  String get aiWeeklyReportHint => _text('aiWeeklyReportHint');
  String get aiWeeklyReportGenerate => _text('aiWeeklyReportGenerate');
  String get aiWeeklyReportLoading => _text('aiWeeklyReportLoading');
  String get aiWeeklyReportSummaryTitle => _text('aiWeeklyReportSummaryTitle');
  String get aiWeeklyReportRegenerate => _text('aiWeeklyReportRegenerate');
  String get aiWeeklyReportNoTasks => _text('aiWeeklyReportNoTasks');
  String get aiWeeklyReportFailed => _text('aiWeeklyReportFailed');
  String get aiWeeklyReportThisWeek => _text('aiWeeklyReportThisWeek');
  String get onboardingWelcomeTitle => _text('onboardingWelcomeTitle');
  String get onboardingWelcomeBody => _text('onboardingWelcomeBody');
  String get onboardingQuickAddTitle => _text('onboardingQuickAddTitle');
  String get onboardingQuickAddBody => _text('onboardingQuickAddBody');
  String get onboardingOrganizeTitle => _text('onboardingOrganizeTitle');
  String get onboardingOrganizeBody => _text('onboardingOrganizeBody');
  String get onboardingInsightsTitle => _text('onboardingInsightsTitle');
  String get onboardingInsightsBody => _text('onboardingInsightsBody');
  String get onboardingSkip => _text('onboardingSkip');
  String get onboardingNext => _text('onboardingNext');
  String get onboardingStart => _text('onboardingStart');
  String get aiChat => _text('aiChat');
  String get aiChatHint => _text('aiChatHint');
  String get aiChatEmpty => _text('aiChatEmpty');
  String get aiChatInputHint => _text('aiChatInputHint');
  String get aiChatSend => _text('aiChatSend');
  String get aiChatLoading => _text('aiChatLoading');
  String get aiChatNoTasksToday => _text('aiChatNoTasksToday');
  String get aiChatReportWeekly => _text('aiChatReportWeekly');
  String get aiChatReportMonthly => _text('aiChatReportMonthly');
  String get aiChatReportYearly => _text('aiChatReportYearly');
  String get aiChatReportFailed => _text('aiChatReportFailed');
  String get aiImageAdd => _text('aiImageAdd');
  String get aiImagePicking => _text('aiImagePicking');
  String get aiImageNoImage => _text('aiImageNoImage');
  String get aiImageInvalid => _text('aiImageInvalid');
  String get aiImageParseFailed => _text('aiImageParseFailed');
  String get aiImageCloudOnly => _text('aiImageCloudOnly');
  String get dailyReportReminder => _text('dailyReportReminder');
  String get dailyReportTime => _text('dailyReportTime');
  String get weeklyReportReminder => _text('weeklyReportReminder');
  String get weeklyReportTime => _text('weeklyReportTime');
  String get weeklyReportDay => _text('weeklyReportDay');
  String get dueAtReminder => _text('dueAtReminder');
  String get dueAtReminderSubtitle => _text('dueAtReminderSubtitle');
  String get dailyReportNotificationTitle =>
      _text('dailyReportNotificationTitle');
  String get weeklyReportNotificationTitle =>
      _text('weeklyReportNotificationTitle');
  String get dueNowNotificationTitle => _text('dueNowNotificationTitle');
  String get created => _text('created');
  String get dueThisWeek => _text('dueThisWeek');
  String get shortcutsGlobal => _text('shortcutsGlobal');
  String get shortcutsAdd => _text('shortcutsAdd');
  String get shortcutsNavigation => _text('shortcutsNavigation');
  String get shortcutsSearch => _text('shortcutsSearch');
  String get shortcutsGeneral => _text('shortcutsGeneral');
  String get globalHotkeyEnabled => _text('globalHotkeyEnabled');
  String get globalHotkeyHint => _text('globalHotkeyHint');
  String get globalHotkeyQuickAdd => _text('globalHotkeyQuickAdd');
  String get shortcutRecorderTitle => _text('shortcutRecorderTitle');
  String get shortcutRecorderHint => _text('shortcutRecorderHint');
  String get shortcutRecorderInvalid => _text('shortcutRecorderInvalid');
  String get shortcutRecorderUnsupported =>
      _text('shortcutRecorderUnsupported');
  String get shortcutQuickAdd => _text('shortcutQuickAdd');
  String get shortcutQuickAddInbox => _text('shortcutQuickAddInbox');
  String get shortcutQuickAddToday => _text('shortcutQuickAddToday');
  String get shortcutSearch => _text('shortcutSearch');
  String get shortcutCommandPalette => _text('shortcutCommandPalette');
  String get shortcutToday => _text('shortcutToday');
  String get shortcutInbox => _text('shortcutInbox');
  String get shortcutUpcoming => _text('shortcutUpcoming');
  String get shortcutCalendar => _text('shortcutCalendar');
  String get shortcutClose => _text('shortcutClose');
  String get clear => _text('clear');
  String get edit => _text('edit');
  String get priority => _text('priority');
  String get priorityNone => _text('priorityNone');
  String get priorityLow => _text('priorityLow');
  String get priorityMedium => _text('priorityMedium');
  String get priorityHigh => _text('priorityHigh');
  String get unknownProject => _text('unknownProject');
  String get lists => _text('lists');
  String get tags => _text('tags');
  String get subtasks => _text('subtasks');
  String get subtasksEmpty => _text('subtasksEmpty');
  String get addSubtask => _text('addSubtask');
  String get parentTask => _text('parentTask');
  String get parentTaskMissing => _text('parentTaskMissing');
  String get subtaskNoNested => _text('subtaskNoNested');
  String get noTags => _text('noTags');
  String get editTags => _text('editTags');
  String get selectTags => _text('selectTags');
  String get tagEmpty => _text('tagEmpty');

  String calendarDayTasks(int count) {
    final template = _text('calendarDayTasks');
    return template.replaceFirst('{count}', count.toString());
  }

  String tasksCount(int count) {
    final template = _text('tasksCount');
    return template.replaceFirst('{count}', count.toString());
  }

  String upcomingSummaryNotificationBody(int count) {
    final template = _text('upcomingSummaryNotificationBody');
    return template.replaceFirst('{count}', count.toString());
  }

  String dueSoonNotificationBody(String title) {
    final template = _text('dueSoonNotificationBody');
    return template.replaceFirst('{title}', title);
  }

  String dueNowNotificationBody(String title) {
    final template = _text('dueNowNotificationBody');
    return template.replaceFirst('{title}', title);
  }

  String dailyReportNotificationBody(int due, int done, int overdue) {
    var template = _text('dailyReportNotificationBody');
    template = template.replaceFirst('{due}', due.toString());
    template = template.replaceFirst('{done}', done.toString());
    template = template.replaceFirst('{overdue}', overdue.toString());
    return template;
  }

  String weeklyReportNotificationBody({
    required int done,
    required int created,
    required int due,
    required int open,
  }) {
    var template = _text('weeklyReportNotificationBody');
    template = template.replaceFirst('{done}', done.toString());
    template = template.replaceFirst('{created}', created.toString());
    template = template.replaceFirst('{due}', due.toString());
    template = template.replaceFirst('{open}', open.toString());
    return template;
  }

  String aiLocalTestModelMissing(String model) {
    final template = _text('aiLocalTestModelMissing');
    return template.replaceAll('{model}', model);
  }

  String aiQuickAddFailedWithReason(String reason) {
    final template = _text('aiQuickAddFailedWithReason');
    return template.replaceAll('{reason}', reason);
  }

  String aiCloudTestFailedWithReasonText(String reason) {
    final template = _text('aiCloudTestFailedWithReason');
    return template.replaceAll('{reason}', reason);
  }

  String subtaskProgress(int done, int total) {
    final template = _text('subtaskProgress');
    return template
        .replaceFirst('{done}', done.toString())
        .replaceFirst('{total}', total.toString());
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
