import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'quick_find.dart';

/// 内容列顶部的工具栏（仅 macOS）。
///
/// 内容列 = sidebar 之外的主区域。把工具栏放在内容列里而不是横跨整窗，
/// 这样：
///   1. sidebar 上方那 28px 完全空着，是 macOS 默认的拖动区，可以拖窗；
///   2. 工具栏的上 28px（高 [titleBarReserve]）也保持空着——同样落在
///      系统标题栏的拖动区里，FlutterView 在这块 hit test 会被 NSWindow
///      吃掉做拖动用，所以不能放交互控件；
///   3. 工具栏剩余 [searchSlotHeight] 那截才放搜索触发器，肯定能点。
///
/// 其他平台 / 非 desktop 时返回 0 高度。
class WindowToolbar extends StatelessWidget {
  const WindowToolbar({super.key});

  /// 系统 title bar 高度——落在这块上的 widget 都接收不到 click，
  /// 因为 NSWindow 在内部把它当拖动区吞掉了。
  static const double titleBarReserve = 28;

  /// 搜索触发器分配的纵向空间（含上下内边距）。
  static const double searchSlotHeight = 28;

  /// 总高度。
  static const double height = titleBarReserve + searchSlotHeight;

  /// 搜索框最大宽度——超出居中显示。
  static const double searchMaxWidth = 420;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return SizedBox(
      height: height,
      child: Container(
        color: theme.colorScheme.surface,
        // 上 28px 留给 NSWindow 拖动区，不放任何 widget。
        padding: const EdgeInsets.fromLTRB(
          FlowSpacing.md,
          titleBarReserve,
          FlowSpacing.md,
          0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: searchMaxWidth),
            child: _SearchTrigger(
              hint: l.searchTasks,
              onTap: () => showQuickFind(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// 搜索框外观但不接收文本输入：点击直接弹 Quick Find 命令面板。
///
/// 不用真 [TextField]，因为它要求获得焦点才显示光标，而我们希望点击立刻
/// 跳到弹窗里那个真正能输入的搜索框。
class _SearchTrigger extends StatelessWidget {
  const _SearchTrigger({
    required this.hint,
    required this.onTap,
  });

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: FlowRadii.brSm,
      child: InkWell(
        borderRadius: FlowRadii.brSm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpacing.md,
            vertical: 6,
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: muted),
              const SizedBox(width: FlowSpacing.sm),
              Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
