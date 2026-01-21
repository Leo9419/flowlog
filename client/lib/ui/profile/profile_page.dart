import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context);
    final isDark = settings.themeMode == ThemeMode.dark;
    final isChinese = settings.locale.languageCode == 'zh';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const CircleAvatar(
            child: Text('F'),
          ),
          title: Text(l.profileUserName),
          subtitle: Text(l.profileTapToLogin),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l.settings),
          onTap: () {},
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
          onTap: () {},
        ),
      ],
    );
  }
}

