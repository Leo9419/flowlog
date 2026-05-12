# M1-02 iOS / iPadOS 工程脚手架

> 给 flowlog 加上 iOS 与 iPadOS 平台支持，与 macOS 共享 Flutter 代码。包含工程创建、Info.plist、通知服务适配、全局热键平台抽象、iPad 多窗口 / 分屏适配。

## 1. 目标

- `flutter run -d ios` 可以在模拟器与真机启动应用并跑到自适应 Shell。
- iPad 横屏自动进入双栏 / 三栏布局（断点交给 M1-04 的 AdaptiveShell）。
- 通知权限正确请求，本地通知能在锁屏弹出。
- 全局热键在 iOS 上做空实现降级，不阻塞编译。

## 2. 现状

- `client/macos/`、`client/android/` 存在；`client/ios/` 不存在（git status 中 `client/android/` 是 `??` 表示新增未提交，但 iOS 完全缺失）。
- 通知服务 `client/lib/services/notification_service.dart` 已支持 macOS + Android，未覆盖 iOS。
- 全局热键 `client/lib/services/global_hotkey_service.dart` 是 macOS Carbon 实现，硬依赖 `Platform.isMacOS`。
- `pubspec.yaml` 的 `flutter.platforms` 节点未声明 ios。

## 3. 工程创建

### 3.1 命令

```bash
cd /Users/mwl/IdeaProjects/flowlog/client
flutter create --platforms=ios .
```

执行后会生成：
```
client/ios/Runner.xcodeproj
client/ios/Runner.xcworkspace
client/ios/Runner/
  AppDelegate.swift
  Info.plist
  Assets.xcassets/
  Base.lproj/LaunchScreen.storyboard
  Runner-Bridging-Header.h
client/ios/Podfile
```

### 3.2 提交策略

- `Runner.xcworkspace/xcuserdata/` 加 `.gitignore`。
- `Pods/` 不入库（已有默认 .gitignore 行为）。
- `Podfile.lock` 入库。

### 3.3 pubspec 同步

`client/pubspec.yaml`：
```yaml
flutter:
  # ...
  # 不需要手动写平台，flutter create 会自动注册插件
```

## 4. Info.plist 配置

文件：`client/ios/Runner/Info.plist`

### 4.1 必加键

| Key | Value | 说明 |
|---|---|---|
| `CFBundleDisplayName` | `FlowLog` | 应用显示名 |
| `LSRequiresIPhoneOS` | `true` | 标准 iOS 应用 |
| `UISupportedInterfaceOrientations` | Portrait, LandscapeLeft, LandscapeRight | iPhone 三方向 |
| `UISupportedInterfaceOrientations~ipad` | 全四向 | iPad 全方向 |
| `UIRequiresFullScreen` | `false` | 允许 iPad 分屏 / Slide Over |
| `UIApplicationSupportsIndirectInputEvents` | `true` | 鼠标 / Magic Keyboard 支持 |
| `UISupportsDocumentBrowser` | `false` | 不需要文档浏览 |

### 4.2 权限说明（NSXxxUsageDescription）

```xml
<key>NSUserNotificationsUsageDescription</key>
<string>FlowLog 在任务到期前提醒你，并发送每日总结。</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>从相册选择图片让 AI 协助识别任务内容。</string>

<key>NSCameraUsageDescription</key>
<string>拍照让 AI 协助识别任务内容。</string>
```

### 4.3 通知与后台

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

> 后期接入服务端推送同步时会用到 `remote-notification`；M1 仅占位。

## 5. Podfile 配置

文件：`client/ios/Podfile`

```ruby
platform :ios, '13.0'

# 末尾 post_install 钩子里追加：
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      # flutter_local_notifications 需要的预处理宏
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

> iOS 13 是 flutter_local_notifications 4.x 的最低要求，且覆盖 99%+ 设备。

## 6. AppDelegate

文件：`client/ios/Runner/AppDelegate.swift`

```swift
import UIKit
import Flutter
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS 10+ 通知通道
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    // flutter_local_notifications 后台调度回调
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 7. 通知服务 iOS 适配

文件：`client/lib/services/notification_service.dart`

### 7.1 初始化

把现有 init 改为：
```dart
final initSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    // 改为延后到用户进入 Settings 后再请求
  ),
  macOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);
```

### 7.2 权限请求时机

- 不在 `main()` 启动时立即请求（会被苹果审核拦截）。
- 在以下时机调用 `requestPermissions`：
  1. 用户首次创建带 `reminderAt` 的任务时
  2. 用户首次进入 Settings 打开"每日总结"
  3. Onboarding 第一屏的"开启提醒"按钮

```dart
Future<bool> ensureIOSPermission() async {
  if (!Platform.isIOS) return true;
  final plugin = FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  return await plugin?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
}
```

### 7.3 时区

```dart
import 'package:flutter_timezone/flutter_timezone.dart';

await tz.initializeTimeZones();
final localTz = await FlutterTimezone.getLocalTimezone();
tz.setLocalLocation(tz.getLocation(localTz));
```

依赖：`pubspec.yaml` 加 `flutter_timezone: ^4.0.0`（如未引入）。

### 7.4 前台展示策略

iOS 默认前台不显示横幅。在 `AppDelegate.swift` 里：

```swift
override func userNotificationCenter(
  _ center: UNUserNotificationCenter,
  willPresent notification: UNNotification,
  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
  completionHandler([.banner, .sound, .badge])
}
```

## 8. 全局热键平台抽象

### 8.1 接口

新建 `client/lib/services/global_hotkey_service.dart`（重写为接口）：

```dart
abstract class GlobalHotkeyService {
  static final GlobalHotkeyService instance = _make();

  static GlobalHotkeyService _make() {
    if (Platform.isMacOS) return MacOsHotkeyService();
    return _NoopHotkeyService();
  }

  Future<void> registerQuickEntry({required VoidCallback onTrigger});
  Future<void> registerToggleWindow({required VoidCallback onTrigger});
  Future<void> unregisterAll();
}

class _NoopHotkeyService implements GlobalHotkeyService {
  @override Future<void> registerQuickEntry({required VoidCallback onTrigger}) async {}
  @override Future<void> registerToggleWindow({required VoidCallback onTrigger}) async {}
  @override Future<void> unregisterAll() async {}
}
```

### 8.2 macOS 实现

把现有 macOS 实现提到 `client/lib/services/global_hotkey_service_macos.dart`，类名 `MacOsHotkeyService`，逻辑不变。

### 8.3 调用点

`client/lib/main.dart` 启动时：
```dart
if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
  await GlobalHotkeyService.instance.registerQuickEntry(onTrigger: ...);
}
```
iOS 自然走 noop。

## 9. iPad 适配

iPad 与 iPhone 共用同一份 iOS 工程，差异点：

| 项 | 配置 |
|---|---|
| 多窗口 | Info.plist `UIApplicationSupportsMultipleScenes=true`（M3 才用，M1 占位）|
| 鼠标 / 触控板 | `UIApplicationSupportsIndirectInputEvents=true` |
| 全方向 | `UISupportedInterfaceOrientations~ipad` 全开 |
| 分屏 / Slide Over | `UIRequiresFullScreen=false` |
| 键盘快捷键 | M3 通过 Flutter `Shortcuts` widget 实现，与桌面端共用一份 binding |

iPad 上的 UI 行为完全由 M1-04 的 `AdaptiveShell` 决定：
- 竖屏（宽度 < 1000）→ TabletShell（双栏）
- 横屏（宽度 ≥ 1000）→ DesktopShell（三栏）

## 10. 文件清单

### 新增
```
client/ios/                                       (整个目录由 flutter create 生成)
client/lib/services/global_hotkey_service.dart    (重写为接口)
client/lib/services/global_hotkey_service_macos.dart
```

### 修改
```
client/ios/Runner/Info.plist                      (权限 / 方向 / 后台)
client/ios/Podfile                                (iOS 13.0 / 预处理宏)
client/ios/Runner/AppDelegate.swift               (通知 delegate / 前台展示)
client/lib/services/notification_service.dart     (iOS 初始化 / 权限延后)
client/lib/main.dart                              (热键调用点改为 instance)
client/pubspec.yaml                               (flutter_timezone 等)
```

## 11. 实施步骤

1. `chore(ios): scaffold via flutter create --platforms=ios` — 仅生成工程，不改业务代码。
2. `chore(ios): tune Info.plist & Podfile for ios 13 baseline`
3. `chore(ios): wire AppDelegate notification delegate`
4. `refactor(hotkey): split GlobalHotkeyService into interface + macOS impl + noop`
5. `feat(notify): defer iOS permission to first-use sites`
6. `chore(ios): build & launch in simulator`（验证）

## 12. 风险与注意事项

| 风险 | 应对 |
|---|---|
| `pod install` 在 Apple Silicon 上找不到 ffi | `arch -x86_64 pod install` 或升级 CocoaPods 1.13+ |
| `flutter_local_notifications` iOS 时区错误 | 必须先 `await tz.initializeTimeZones()` 再 `setLocalLocation` |
| Drift sqlite3_flutter_libs iOS 编译报错 | 在 Podfile 加 `use_frameworks!`（已是默认） |
| 真机调试需要 Apple ID | 文档里说明，第一次需登录 Xcode → Signing & Capabilities |
| 苹果审核拒绝 NSUserNotificationsUsageDescription | iOS 没有这个 key，不要写；只用 `UIBackgroundModes` + 运行时 `requestPermissions`。修正：移除上面 4.2 的 `NSUserNotificationsUsageDescription`（Apple 文档无此 key） |

> 注：Apple 实际上 **没有** `NSUserNotificationsUsageDescription` 这个 key（那是 macOS 旧 API 的命名），iOS 的通知权限走运行时 `UNUserNotificationCenter.requestAuthorization`，无需 plist 描述。M1 实施时按本节 4.2 删除该 key。

## 13. 验收标准

1. ✅ `flutter run -d "iPhone 15"` 启动到 AdaptiveShell 主界面，无红屏。
2. ✅ `flutter run -d "iPad Pro (12.9-inch)"` 横屏自动三栏，竖屏双栏。
3. ✅ Onboarding 点击"开启提醒"后，模拟器弹出系统通知权限弹窗。
4. ✅ 创建带 reminderAt 的任务后，`xcrun simctl push` 或自然到点能在锁屏看到通知。
5. ✅ 旋转 iPad 模拟器，布局平滑切换。
6. ✅ macOS 全局热键功能未回退。
