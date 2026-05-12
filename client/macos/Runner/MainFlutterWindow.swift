import Cocoa
import FlutterMacOS
import Carbon.HIToolbox

class MainFlutterWindow: NSWindow {
  private var launchPlaceholderView: NSView?
  private let launchChannelName = "flowlog/launch"
  private let hotkeyChannelName = "flowlog/hotkey"
  private var hotKeyChannel: FlutterMethodChannel?
  private var hotKeyRef: EventHotKeyRef?
  private var hotKeyHandlerRef: EventHandlerRef?
  private let hotKeySignature: OSType = 0x464C4F47 // 'FLOG'

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.backgroundColor = NSColor.windowBackgroundColor
    self.isOpaque = true

    // 隐藏 macOS 自带的窗口标题文字（"FlowLog"），让 traffic light 浮在
    // 内容之上；同时把 Flutter 内容延伸到 title bar 区域，便于在那里
    // 放置自定义工具栏（搜索框等）。
    //
    // 注意：不能开 `isMovableByWindowBackground = true`——那会让整个窗口
    // 背景成为拖动起点、把 Flutter TextField 的点击事件吞掉。系统默认
    // title bar 顶部 ~28px 区域仍然可以拖窗，足够。
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)

    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    showLaunchPlaceholder(on: flutterViewController.view)
    setupLaunchChannel(flutterViewController)
    setupHotKeyChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func setupLaunchChannel(_ flutterViewController: FlutterViewController) {
    let messenger = flutterViewController.engine.binaryMessenger
    let channel = FlutterMethodChannel(name: launchChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "ready" {
        self?.removeLaunchPlaceholder()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
      self?.removeLaunchPlaceholder()
    }
  }

  private func setupHotKeyChannel(_ flutterViewController: FlutterViewController) {
    let messenger = flutterViewController.engine.binaryMessenger
    let channel = FlutterMethodChannel(name: hotkeyChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "register":
        guard let args = call.arguments as? [String: Any],
              let key = args["key"] as? String,
              let modifiers = args["modifiers"] as? [String] else {
          result(FlutterError(code: "invalid_args", message: "Missing key/modifiers", details: nil))
          return
        }
        self?.registerHotKey(key: key, modifiers: modifiers)
        result(nil)
      case "unregister":
        self?.unregisterHotKey()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    hotKeyChannel = channel
  }

  private func registerHotKey(key: String, modifiers: [String]) {
    unregisterHotKey()
    guard let keyCode = keyCodeForKey(key) else {
      return
    }

    let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
    let modifierFlags = carbonModifiers(from: modifiers)
    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    if status == noErr {
      hotKeyRef = ref
      installHotKeyHandlerIfNeeded()
    }
  }

  private func unregisterHotKey() {
    if let ref = hotKeyRef {
      UnregisterEventHotKey(ref)
      hotKeyRef = nil
    }
  }

  private func installHotKeyHandlerIfNeeded() {
    if hotKeyHandlerRef != nil {
      return
    }
    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    InstallEventHandler(
      GetApplicationEventTarget(),
      { (_, _, userData) -> OSStatus in
        if let userData = userData {
          let window = Unmanaged<MainFlutterWindow>.fromOpaque(userData).takeUnretainedValue()
          window.handleHotKey()
        }
        return noErr
      },
      1,
      &eventSpec,
      selfPointer,
      &hotKeyHandlerRef
    )
  }

  private func handleHotKey() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if NSApp.isActive {
        return
      }
      NSApp.activate(ignoringOtherApps: true)
      self.makeKeyAndOrderFront(nil)
      self.hotKeyChannel?.invokeMethod("trigger", arguments: ["target": "inbox"])
    }
  }

  private func carbonModifiers(from modifiers: [String]) -> UInt32 {
    var result: UInt32 = 0
    for modifier in modifiers {
      switch modifier {
      case "meta":
        result |= UInt32(cmdKey)
      case "alt":
        result |= UInt32(optionKey)
      case "shift":
        result |= UInt32(shiftKey)
      case "control":
        result |= UInt32(controlKey)
      default:
        break
      }
    }
    return result
  }

  private func keyCodeForKey(_ key: String) -> UInt32? {
    switch key.uppercased() {
    case "A": return UInt32(kVK_ANSI_A)
    case "B": return UInt32(kVK_ANSI_B)
    case "C": return UInt32(kVK_ANSI_C)
    case "D": return UInt32(kVK_ANSI_D)
    case "E": return UInt32(kVK_ANSI_E)
    case "F": return UInt32(kVK_ANSI_F)
    case "G": return UInt32(kVK_ANSI_G)
    case "H": return UInt32(kVK_ANSI_H)
    case "I": return UInt32(kVK_ANSI_I)
    case "J": return UInt32(kVK_ANSI_J)
    case "K": return UInt32(kVK_ANSI_K)
    case "L": return UInt32(kVK_ANSI_L)
    case "M": return UInt32(kVK_ANSI_M)
    case "N": return UInt32(kVK_ANSI_N)
    case "O": return UInt32(kVK_ANSI_O)
    case "P": return UInt32(kVK_ANSI_P)
    case "Q": return UInt32(kVK_ANSI_Q)
    case "R": return UInt32(kVK_ANSI_R)
    case "S": return UInt32(kVK_ANSI_S)
    case "T": return UInt32(kVK_ANSI_T)
    case "U": return UInt32(kVK_ANSI_U)
    case "V": return UInt32(kVK_ANSI_V)
    case "W": return UInt32(kVK_ANSI_W)
    case "X": return UInt32(kVK_ANSI_X)
    case "Y": return UInt32(kVK_ANSI_Y)
    case "Z": return UInt32(kVK_ANSI_Z)
    case "0": return UInt32(kVK_ANSI_0)
    case "1": return UInt32(kVK_ANSI_1)
    case "2": return UInt32(kVK_ANSI_2)
    case "3": return UInt32(kVK_ANSI_3)
    case "4": return UInt32(kVK_ANSI_4)
    case "5": return UInt32(kVK_ANSI_5)
    case "6": return UInt32(kVK_ANSI_6)
    case "7": return UInt32(kVK_ANSI_7)
    case "8": return UInt32(kVK_ANSI_8)
    case "9": return UInt32(kVK_ANSI_9)
    case "SPACE": return UInt32(kVK_Space)
    default:
      return nil
    }
  }

  private func showLaunchPlaceholder(on view: NSView) {
    let placeholder = NSView()
    placeholder.translatesAutoresizingMaskIntoConstraints = false
    placeholder.wantsLayer = true
    placeholder.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

    let title = NSTextField(labelWithString: "FlowLog")
    title.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
    title.textColor = NSColor.secondaryLabelColor
    title.alignment = .center

    let stack = NSStackView(views: [title])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false

    placeholder.addSubview(stack)
    view.addSubview(placeholder)

    NSLayoutConstraint.activate([
      placeholder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      placeholder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      placeholder.topAnchor.constraint(equalTo: view.topAnchor),
      placeholder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      stack.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor),
    ])

    launchPlaceholderView = placeholder
  }

  private func removeLaunchPlaceholder() {
    guard let placeholder = launchPlaceholderView else {
      return
    }
    launchPlaceholderView = nil
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.2
      placeholder.animator().alphaValue = 0
    }, completionHandler: {
      placeholder.removeFromSuperview()
    })
  }
}
