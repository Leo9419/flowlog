import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_settings.dart';
import 'ai_settings_page.dart';
import 'notifications_page.dart';
import 'shortcuts_page.dart';
import '../projects/project_manage_page.dart';
import '../tags/tag_manage_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context);
    final isDark = settings.themeMode == ThemeMode.dark;
    final isChinese = settings.locale.languageCode == 'zh';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: Text(l.manageProjects),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProjectManagePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(l.manageTags),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagManagePage()),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: Text(isDark ? l.themeDark : l.themeLight),
            value: isDark,
            onChanged: (value) {
              settings.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l.language),
            subtitle: Text(isChinese ? l.languageChinese : l.languageEnglish),
            onTap: () {
              settings.setLocale(
                isChinese ? const Locale('en') : const Locale('zh'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l.notifications),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l.aiSettings),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: Text(l.shortcuts),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShortcutsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
