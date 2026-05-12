import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

// M1_02：FlowLog iOS 入口。
//
// 在 Flutter 默认实现的基础上：
//   1. 把自己挂为 `UNUserNotificationCenter.delegate`，这样 iOS 10+
//      在前台和锁屏 / 通知中心都能正确分发通知到 Flutter 端。
//   2. 注册 `setPluginRegistrantCallback`，让 flutter_local_notifications
//      在后台被系统拉起时也能调度 Flutter plugin（否则定时通知到点会
//      静默失败）。
//   3. 覆写 `willPresent`，让 App 在前台时也弹横幅 + 声音 + 角标。
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 前台收到通知时的展示策略。FlutterAppDelegate 默认会吞掉横幅，
  // 这里显式打开 banner + sound + badge，与 macOS / Android 表现一致。
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
