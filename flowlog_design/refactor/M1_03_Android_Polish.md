# M1-03 Android 完整化

> 现有 `client/android/` 还是脚手架，需要补齐：SDK 版本、通知与精确闹钟权限、Material You 动态色、Android 13+ 通知运行时权限请求流程。

## 1. 目标

- `flutter run` 在 Android 13+ 真机能正常启动并请求通知权限。
- 应用 Material You 动态主题（Android 12+ 取系统强调色）。
- 本地通知能在锁屏弹出，精确闹钟（任务到点提醒）不被系统延后。
- 与 iOS / macOS 共用一份 Flutter 业务代码。

## 2. 现状

- `client/android/` 已存在（git status 显示新增），结构是 `flutter create` 默认。
- `client/lib/services/notification_service.dart` 已支持 Android 通道，但未处理 Android 13+ 运行时通知权限。
- 主题在 `client/lib/main.dart` 写死粉色种子色，未对接 Material You。
- `pubspec.yaml` 未引入 `permission_handler` / `dynamic_color`。

## 3. SDK 与构建配置

文件：`client/android/app/build.gradle`（或 `build.gradle.kts`）

```gradle
android {
    namespace "com.flowlog.app"      // 与 macOS bundle id 对齐
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.flowlog.app"
        minSdkVersion 23              // Android 6.0+，覆盖 99% 设备
        targetSdkVersion 34           // 必须 ≥34（2024 年 8 月起 Play 要求）
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true   // flutter_local_notifications 需要
    }

    kotlinOptions {
        jvmTarget = '17'
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

`client/android/build.gradle` 顶层：
```gradle
ext.kotlin_version = '1.9.10'
```

`client/android/gradle/wrapper/gradle-wrapper.properties`：
```
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
```

## 4. AndroidManifest 权限

文件：`client/android/app/src/main/AndroidManifest.xml`

### 4.1 顶层 `<manifest>` 内权限

```xml
<!-- 通知（Android 13+ 必须运行时请求） -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 精确闹钟（任务到点提醒） -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<!-- 开机启动后恢复定时通知 -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- 振动 -->
<uses-permission android:name="android.permission.VIBRATE" />

<!-- 网络（AI 服务、未来同步） -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- 选图（AI 图片识别） -->
<!-- file_picker 已自动声明，无需重复 -->
```

### 4.2 `<application>` 标签内

```xml
<application
    android:label="FlowLog"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:enableOnBackInvokedCallback="true">    <!-- 预测式返回手势 -->

    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTop"
        android:theme="@style/LaunchTheme"
        android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
        android:hardwareAccelerated="true"
        android:windowSoftInputMode="adjustResize">
        <meta-data
            android:name="io.flutter.embedding.android.NormalTheme"
            android:resource="@style/NormalTheme" />
        <intent-filter>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent-filter>
    </activity>

    <!-- flutter_local_notifications 必备 receiver -->
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>
</application>
```

## 5. Material You 动态主题

### 5.1 依赖

`client/pubspec.yaml`：
```yaml
dependencies:
  dynamic_color: ^1.7.0
```

### 5.2 main.dart 接入

修改 `client/lib/main.dart`：

```dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flowlog/theme/app_theme.dart';

return DynamicColorBuilder(
  builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
    return MaterialApp(
      theme: appLightTheme(seed: lightDynamic?.primary),
      darkTheme: appDarkTheme(seed: darkDynamic?.primary),
      themeMode: ThemeMode.system,
      home: const AdaptiveShell(),
    );
  },
);
```

`appLightTheme(seed)` / `appDarkTheme(seed)` 由 M1-05 提供，签名约定：
- `seed == null` → 用品牌色（蓝色 / 当前粉色，由 M1-05 决定）
- `seed != null` → Android 12+ 系统色，作为 `ColorScheme.fromSeed` 的种子

### 5.3 平台行为

| 平台 | dynamic_color 返回 |
|---|---|
| Android 12+ | 系统强调色（壁纸取色）|
| Android 11 及以下 | `null`，回退品牌色 |
| iOS / macOS | `null`，回退品牌色（系统不暴露）|

## 6. 通知服务运行时权限

### 6.1 依赖

`client/pubspec.yaml`：
```yaml
dependencies:
  permission_handler: ^11.3.0
```

### 6.2 通知权限请求

`client/lib/services/notification_service.dart` 加：

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureAndroidNotificationPermission() async {
  if (!Platform.isAndroid) return true;

  // Android 13+ 才有 POST_NOTIFICATIONS 运行时权限
  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (sdkInt < 33) return true;

  final status = await Permission.notification.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) {
    // 用户已永久拒绝，跳设置页（由 UI 决定是否调用）
    return false;
  }
  final result = await Permission.notification.request();
  return result.isGranted;
}
```

> 依赖 `device_info_plus` 已是常用库；如未引入，加 `device_info_plus: ^10.1.0`。

### 6.3 精确闹钟权限（Android 12+）

```dart
Future<bool> ensureExactAlarmPermission() async {
  if (!Platform.isAndroid) return true;
  final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  if (sdkInt < 31) return true;

  final status = await Permission.scheduleExactAlarm.status;
  if (status.isGranted) return true;
  // 用户必须主动去系统设置开启，无法弹窗
  await openAppSettings();
  return await Permission.scheduleExactAlarm.isGranted;
}
```

### 6.4 请求时机

与 iOS 一致：
- 第一次创建带 `reminderAt` 的任务时
- 第一次进入"每日总结"开关
- Onboarding 第一屏的"开启提醒"按钮

> **不在 main() 里请求**。Android 13+ 启动即弹通知权限会被用户秒拒。

## 7. 启动屏 / 应用图标

### 7.1 启动屏

`client/android/app/src/main/res/values/styles.xml`：
```xml
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```
`values-night/styles.xml` 同步加 dark 版（windowBackground 用深色）。

### 7.2 应用图标

- `client/android/app/src/main/res/mipmap-*` 占位用 flutter create 默认 icon。
- M4 阶段统一替换为 FlowLog 品牌图标。

## 8. 文件清单

### 修改
```
client/android/build.gradle                              # kotlin_version
client/android/app/build.gradle                          # SDK / desugar
client/android/app/src/main/AndroidManifest.xml          # 权限 / receiver
client/android/gradle/wrapper/gradle-wrapper.properties  # gradle 8.4
client/lib/services/notification_service.dart            # Android 13 / 精确闹钟
client/lib/main.dart                                     # DynamicColorBuilder
client/pubspec.yaml                                      # dynamic_color / permission_handler / device_info_plus
```

### 不变
```
client/android/app/src/main/kotlin/.../MainActivity.kt   # M1 阶段不需要写原生代码
```

## 9. 实施步骤

1. `chore(android): bump SDK to 34, kotlin 1.9, gradle 8.4`
2. `chore(android): declare notification & exact alarm permissions`
3. `chore(android): register flutter_local_notifications boot receiver`
4. `feat(theme): wire DynamicColorBuilder for Material You`
5. `feat(notify): runtime POST_NOTIFICATIONS request on Android 13+`
6. `chore(android): verify on Pixel 7 (API 34) emulator`

## 10. 风险与注意事项

| 风险 | 应对 |
|---|---|
| `targetSdk 34` 后台限制更严 | 通知用 WorkManager / AlarmManager 调度（flutter_local_notifications 已封装） |
| `SCHEDULE_EXACT_ALARM` 被 Play 商店审核拒 | 上架时声明用途："任务到点精确提醒"，并提供"使用近似闹钟"开关作为降级 |
| Material You 在 Android 11 闪烁 | dynamic_color 在低版本返回 null，记得做空判断 |
| Gradle 8.4 与旧 Kotlin DSL 不兼容 | 同步升级 `kotlin_version` 至 1.9.10 |
| 桌面端误请求 Android 权限 | `ensureAndroidNotificationPermission` 内置 `Platform.isAndroid` 短路 |
| AGP 与 Flutter 版本错配 | 跑 `flutter doctor -v` 确认 AGP ≥ 8.1，必要时升级 Flutter SDK |

## 11. 验收标准

1. ✅ `flutter run -d <android>` 在 Pixel 7 模拟器（API 34）启动到主界面，无 ANR。
2. ✅ Onboarding 点击"开启提醒"后，弹出系统通知权限对话框，授予后能收到测试通知。
3. ✅ 系统设置壁纸改色后，重启应用主题强调色跟随变化（Material You 生效）。
4. ✅ 创建一个 5 分钟后到期的任务，锁屏 + 灭屏后准点收到通知。
5. ✅ Android 11 模拟器上无 dynamic_color 报错，回退品牌色正常。
6. ✅ `flutter build apk --release` 产物 < 30MB，可安装运行。
