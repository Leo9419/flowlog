import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/selection_store.dart';
import '../../theme/tokens.dart';
import '../settings/settings_page.dart';
import '../trash/trash_page.dart';

/// 弹出 Things 3 风的 Quick Find 命令面板。
///
/// 作用：
/// * 顶部搜索输入（query 对静态项做前缀/包含过滤）
/// * "最近" 分组展示 6 个高频跳转：Inbox / Today / Calendar /
///   Someday / Logbook / Trash
/// * 选中项打勾——表示当前正在浏览的视图
/// * 点击：sidebar 视图走 SelectionStore.selectView；Trash / Settings
///   走 Navigator.push（这两个不是 view，而是独立页面）
///
/// M2 会扩展：搜索任务标题、Tags、命令（"+ 新建任务"）。
Future<void> showQuickFind(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'QuickFind',
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (_, __, ___) => const _QuickFindDialog(),
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _QuickFindDialog extends StatefulWidget {
  const _QuickFindDialog();

  @override
  State<_QuickFindDialog> createState() => _QuickFindDialogState();
}

class _QuickFindDialogState extends State<_QuickFindDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.text == _query) return;
      setState(() => _query = _controller.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final currentView = context.watch<SelectionStore>().state.view;

    final items = _buildItems(context, l, currentView);
    final filtered = _query.trim().isEmpty
        ? items
        : items
            .where((it) =>
                it.label.toLowerCase().contains(_query.trim().toLowerCase()))
            .toList();

    return Align(
      alignment: const Alignment(0, -0.55),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Material(
          // M3 menu / popover 风：圆角 + 浅边线 + 略微浮起，但不重阴影。
          color: theme.colorScheme.surface,
          elevation: 16,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: FlowRadii.brXl,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FlowSpacing.md,
              vertical: FlowSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _searchInput(theme, l),
                const SizedBox(height: FlowSpacing.lg),
                _sectionHeader(theme, l.quickFindRecent),
                const SizedBox(height: FlowSpacing.xs),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: FlowSpacing.sm),
                _itemsList(filtered, currentView),
                const SizedBox(height: FlowSpacing.lg),
                _hint(theme, l.quickFindHint),
                const SizedBox(height: FlowSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchInput(ThemeData theme, AppLocalizations l) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: FlowRadii.brMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FlowSpacing.md),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: muted),
            const SizedBox(width: FlowSpacing.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: theme.textTheme.bodyMedium,
                cursorColor: theme.colorScheme.primary,
                onSubmitted: (_) => _activateFirst(context, l),
                decoration: InputDecoration(
                  hintText: l.quickFind,
                  hintStyle:
                      theme.textTheme.bodyMedium?.copyWith(color: muted),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: FlowSpacing.md),
                  isDense: true,
                ),
              ),
            ),
            // Esc 关闭由 barrierDismissible + 系统默认 ESC dismiss 提供，
            // 用户也可以点击外部空白关闭。
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String text) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FlowSpacing.xs),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _itemsList(List<_QuickItem> items, SidebarView currentView) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: FlowSpacing.lg),
        child: Text(
          AppLocalizations.of(context).searchEmpty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final it in items) _itemRow(it, currentView),
      ],
    );
  }

  Widget _itemRow(_QuickItem item, SidebarView currentView) {
    final theme = Theme.of(context);
    final isCurrent = item.view == currentView;
    return Material(
      color: Colors.transparent,
      borderRadius: FlowRadii.brSm,
      child: InkWell(
        borderRadius: FlowRadii.brSm,
        onTap: () => _activate(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpacing.sm,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: item.color),
              const SizedBox(width: FlowSpacing.md),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCurrent)
                Icon(
                  Icons.check,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FlowSpacing.lg),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  /// 把当前可见的 6 个跳转项构造为 [_QuickItem]。
  List<_QuickItem> _buildItems(
    BuildContext context,
    AppLocalizations l,
    SidebarView currentView,
  ) {
    return [
      _QuickItem(
        view: SidebarView.inbox,
        icon: Icons.inbox_outlined,
        label: l.inbox,
        color: const Color(0xFF7B8794),
        onSelect: (ctx) =>
            ctx.read<SelectionStore>().selectView(SidebarView.inbox),
      ),
      _QuickItem(
        view: SidebarView.today,
        icon: Icons.wb_sunny_outlined,
        label: l.today,
        color: const Color(0xFFFFB800),
        onSelect: (ctx) =>
            ctx.read<SelectionStore>().selectView(SidebarView.today),
      ),
      _QuickItem(
        view: SidebarView.upcoming,
        icon: Icons.calendar_month_outlined,
        label: l.calendar,
        color: const Color(0xFFFF3B6B),
        onSelect: (ctx) =>
            ctx.read<SelectionStore>().selectView(SidebarView.upcoming),
      ),
      _QuickItem(
        view: SidebarView.someday,
        icon: Icons.archive_outlined,
        label: l.someday,
        color: const Color(0xFF9F84BD),
        onSelect: (ctx) =>
            ctx.read<SelectionStore>().selectView(SidebarView.someday),
      ),
      _QuickItem(
        view: SidebarView.logbook,
        icon: Icons.checklist_rtl,
        label: l.logbook,
        color: const Color(0xFF6B7280),
        onSelect: (ctx) =>
            ctx.read<SelectionStore>().selectView(SidebarView.logbook),
      ),
      _QuickItem(
        // Trash 在 sidebar 上是独立页面而非 view，所以 view 字段用 trash 占位
        // 但 onSelect 走 Navigator.push。
        view: SidebarView.trash,
        icon: Icons.delete_outline,
        label: l.trash,
        color: const Color(0xFFAEB4BC),
        onSelect: (ctx) => Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const TrashPage()),
        ),
      ),
      _QuickItem(
        view: SidebarView.settings,
        icon: Icons.settings_outlined,
        label: l.settings,
        color: const Color(0xFFAEB4BC),
        onSelect: (ctx) => Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        ),
      ),
    ];
  }

  void _activate(BuildContext context, _QuickItem item) {
    // 先关弹窗，再触发动作——否则 Navigator.push 会在 dialog route 之上叠一层，
    // 关闭流程混乱。
    final navigator = Navigator.of(context, rootNavigator: true);
    final outerContext =
        Navigator.of(context, rootNavigator: true).context;
    navigator.pop();
    item.onSelect(outerContext);
  }

  void _activateFirst(BuildContext context, AppLocalizations l) {
    final currentView = context.read<SelectionStore>().state.view;
    final items = _buildItems(context, l, currentView);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? items
        : items.where((it) => it.label.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) return;
    _activate(context, filtered.first);
  }
}

/// Quick Find 列表项的不可变描述。
class _QuickItem {
  const _QuickItem({
    required this.view,
    required this.icon,
    required this.label,
    required this.color,
    required this.onSelect,
  });

  final SidebarView view;
  final IconData icon;
  final String label;
  final Color color;

  /// 命中时的动作；接受 dialog 已关闭后的 outer context。
  final void Function(BuildContext context) onSelect;
}

/// 用于注册 Esc 关闭 / 后续 Cmd+K 触发的 Intent。
class OpenQuickFindIntent extends Intent {
  const OpenQuickFindIntent();
}

/// 让全局 Shortcuts 可以挂这个 Action：在 AdaptiveShell 外层包一层
/// `Shortcuts(...)` + `Actions(...)` 便能用 Cmd+K 打开 Quick Find。
/// M1 阶段不强制接入；交给 M2 与 GlobalHotkeyService 一起做。
class OpenQuickFindAction extends Action<OpenQuickFindIntent> {
  OpenQuickFindAction(this.context);
  final BuildContext context;

  @override
  Object? invoke(OpenQuickFindIntent intent) {
    showQuickFind(context);
    return null;
  }
}

/// 屏蔽 keyboard event 不进入下层 widget；这里只暴露给将来 KeyListener 用。
// ignore: unused_element
KeyEventResult _swallowEnter(FocusNode node, KeyEvent event) =>
    event.logicalKey == LogicalKeyboardKey.enter
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
