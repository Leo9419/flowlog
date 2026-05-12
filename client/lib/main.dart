import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database.dart';
import 'l10n/app_localizations.dart';
import 'services/ai_local_service.dart';
import 'services/ai_local_agent_service.dart';
import 'services/ai_cloud_service.dart';
import 'services/global_hotkey_service.dart';
import 'services/notification_service.dart';
import 'state/app_commands.dart';
import 'state/app_settings.dart';
import 'state/selection_store.dart';
import 'theme/app_theme.dart';
import 'ui/onboarding/onboarding_page.dart';
import 'ui/shell/adaptive_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();
  final settings = AppSettings(prefs);
  final commands = AppCommandBus();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (context) => db,
          dispose: (context, db) => db.close(),
        ),
        ChangeNotifierProvider<AppSettings>(
          create: (_) => settings,
        ),
        Provider<AiLocalService>(
          create: (_) => AiLocalService(settings),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<AiCloudService>(
          create: (_) => AiCloudService(settings),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<AiLocalAgentService>(
          create: (_) => AiLocalAgentService(settings),
        ),
        Provider<AppCommandBus>(
          create: (_) => commands,
          dispose: (_, bus) => bus.dispose(),
        ),
        ChangeNotifierProvider<SelectionStore>(
          create: (_) => SelectionStore(),
        ),
      ],
      child: AppBootstrap(db: db, settings: settings),
    ),
  );
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.db,
    required this.settings,
  });

  final AppDatabase db;
  final AppSettings settings;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static const MethodChannel _launchChannel = MethodChannel('flowlog/launch');
  bool _bound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindNotifications();
      _bindGlobalHotkeys();
      _notifyLaunchReady();
    });
  }

  Future<void> _bindNotifications() async {
    if (_bound) return;
    _bound = true;
    try {
      await NotificationService.instance.bind(
        db: widget.db,
        settings: widget.settings,
      );
    } catch (error, stackTrace) {
      debugPrint('Notification init failed: $error');
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> _bindGlobalHotkeys() async {
    try {
      final commands = Provider.of<AppCommandBus>(context, listen: false);
      await GlobalHotkeyService.instance.bind(
        settings: widget.settings,
        commands: commands,
      );
    } catch (error, stackTrace) {
      debugPrint('Global hotkey init failed: $error');
      debugPrint(stackTrace.toString());
    }
  }

  Future<void> _notifyLaunchReady() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _launchChannel.invokeMethod('ready');
    } catch (error) {
      debugPrint('Launch ready signal failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const FlowLogApp();
  }
}

class FlowLogApp extends StatelessWidget {
  const FlowLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    // M1_03 + M1_05：主题入口集中到 theme/app_theme.dart，外层用
    // DynamicColorBuilder 取系统色作为 seed —— Android 12+ 跟随壁纸色，
    // Android 11- / iOS / macOS 返回 null 自动回退品牌色（FlowBrand.primary）。
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'FlowLog',
          theme: appLightTheme(seed: lightDynamic?.primary),
          darkTheme: appDarkTheme(seed: darkDynamic?.primary),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: settings.onboardingCompleted
              ? const AdaptiveShell()
              : const OnboardingPage(),
        );
      },
    );
  }
}
