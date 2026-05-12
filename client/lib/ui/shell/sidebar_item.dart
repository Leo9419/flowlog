import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/selection_store.dart';
import '../../theme/tokens.dart';

/// Sidebar 列表项 —— hover/selected 状态、可选 leading 颜色点、计数 badge。
///
/// 与 [SelectionStore] 解耦：调用方传入 [view] 与可选 [entityId]，组件
/// 自己监听当前选中态、点击时调用 `selectView(...)`。
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.view,
    this.entityId,
    required this.icon,
    this.activeIcon,
    required this.label,
    this.color,
    this.count,
    this.onTapOverride,
  });

  final SidebarView view;
  final String? entityId;
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// 项目色 / Tag 色等点缀色；为 null 时用主题前景色。
  final Color? color;

  /// 任务计数 badge；null 或 0 时不显示。
  final int? count;

  /// 自定义点击行为（如打开 Trash / Settings 这种独立页面而非切换 view）。
  /// 提供时，默认 selectView 不会触发。
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = context.watch<SelectionStore>().state;
    final isSelected = onTapOverride == null &&
        selection.view == view &&
        selection.entityId == entityId;

    final iconWidget = Icon(
      isSelected && activeIcon != null ? activeIcon : icon,
      size: 18,
      color: color ?? theme.colorScheme.onSurface,
    );

    final textColor = isSelected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpacing.sm,
        vertical: FlowSpacing.xxs,
      ),
      child: Material(
        color: isSelected
            ? theme.colorScheme.surfaceContainerHigh
            : Colors.transparent,
        borderRadius: FlowRadii.brMd,
        child: InkWell(
          borderRadius: FlowRadii.brMd,
          onTap: () {
            if (onTapOverride != null) {
              onTapOverride!();
              return;
            }
            context.read<SelectionStore>().selectView(view, entityId: entityId);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FlowSpacing.md,
              vertical: 8,
            ),
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: FlowSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count != null && count! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: FlowSpacing.sm),
                    child: Text(
                      count.toString(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
