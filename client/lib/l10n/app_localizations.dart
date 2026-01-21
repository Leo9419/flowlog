import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'appTitle': 'FlowLog',
      'today': '今天',
      'inbox': '任务箱',
      'calendar': '日历',
      'profile': '我的',
      'addTaskToToday': '添加任务到 \"今天\"',
      'todayEmpty': '今天没有任务，享受生活吧！',
      'todayLabel': '今天',
      'inboxTaskTitle': '收集箱任务',
      'noDueDate': '未设置截止时间',
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
    },
    'en': {
      'appTitle': 'FlowLog',
      'today': 'Today',
      'inbox': 'Inbox',
      'calendar': 'Calendar',
      'profile': 'Me',
      'addTaskToToday': 'Add task to "Today"',
      'todayEmpty': 'No tasks today. Enjoy your time!',
      'todayLabel': 'Today',
      'inboxTaskTitle': 'Inbox task',
      'noDueDate': 'No due date',
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
    },
  };

  String _text(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  String get appTitle => _text('appTitle');
  String get today => _text('today');
  String get inbox => _text('inbox');
  String get calendar => _text('calendar');
  String get profile => _text('profile');
  String get addTaskToToday => _text('addTaskToToday');
  String get todayEmpty => _text('todayEmpty');
  String get todayLabel => _text('todayLabel');
  String get inboxTaskTitle => _text('inboxTaskTitle');
  String get noDueDate => _text('noDueDate');
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

  String calendarDayTasks(int count) {
    final template = _text('calendarDayTasks');
    return template.replaceFirst('{count}', count.toString());
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
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
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

