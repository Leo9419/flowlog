import 'package:flowlog_client/l10n/app_localizations.dart';
import 'package:flowlog_client/state/app_settings.dart';
import 'package:flowlog_client/ui/settings/ai_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Claude Code test button handles a missing service provider',
      (tester) async {
    SharedPreferences.setMockInitialValues({'ai_provider': 'claude_code'});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AiSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.terminal_outlined));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
