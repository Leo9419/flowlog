import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_settings.dart';

class ShortcutsPage extends StatelessWidget {
  const ShortcutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<AppSettings>(context);
    final hotkey = settings.globalQuickAddHotkey;
    final hotkeyEnabled = settings.globalQuickAddEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.shortcuts),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l.shortcutsHint,
            style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _ShortcutSection(
            title: l.shortcutsGlobal,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.public_outlined),
                title: Text(l.globalHotkeyEnabled),
                subtitle: Text(l.globalHotkeyHint),
                value: hotkeyEnabled,
                onChanged: (value) async {
                  await settings.setGlobalQuickAddEnabled(value);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: Text(l.globalHotkeyQuickAdd),
                enabled: hotkeyEnabled,
                trailing: _ShortcutKeys(keys: hotkey.keyCaps()),
                onTap: hotkeyEnabled
                    ? () async {
                        final updated = await showDialog<GlobalHotkeyConfig>(
                          context: context,
                          builder: (_) => _HotkeyRecorderDialog(
                            initial: hotkey,
                          ),
                        );
                        if (updated != null) {
                          await settings.setGlobalQuickAddHotkey(updated);
                        }
                      }
                    : null,
              ),
            ],
          ),
          _ShortcutSection(
            title: l.shortcutsAdd,
            children: [
              _ShortcutRow(label: l.shortcutQuickAdd, keys: const ['Cmd', 'N']),
              _ShortcutRow(label: l.shortcutQuickAddInbox, keys: const ['Cmd', 'Shift', 'N']),
              _ShortcutRow(label: l.shortcutQuickAddToday, keys: const ['Cmd', 'Option', 'N']),
            ],
          ),
          _ShortcutSection(
            title: l.shortcutsNavigation,
            children: [
              _ShortcutRow(label: l.shortcutToday, keys: const ['Cmd', '1']),
              _ShortcutRow(label: l.shortcutInbox, keys: const ['Cmd', '2']),
              _ShortcutRow(label: l.shortcutUpcoming, keys: const ['Cmd', '3']),
              _ShortcutRow(label: l.shortcutCalendar, keys: const ['Cmd', '4']),
            ],
          ),
          _ShortcutSection(
            title: l.shortcutsSearch,
            children: [
              _ShortcutRow(label: l.shortcutSearch, keys: const ['Cmd', 'F']),
              _ShortcutRow(label: l.shortcutCommandPalette, keys: const ['Cmd', 'K']),
            ],
          ),
          _ShortcutSection(
            title: l.shortcutsGeneral,
            children: [
              _ShortcutRow(label: l.shortcutClose, keys: const ['Esc']),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.label,
    required this.keys,
  });

  final String label;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label),
          ),
          _ShortcutKeys(keys: keys),
        ],
      ),
    );
  }
}

class _ShortcutKeys extends StatelessWidget {
  const _ShortcutKeys({required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyTextStyle = theme.textTheme.labelMedium;
    final separatorStyle = theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600]);
    final children = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('+', style: separatorStyle),
        ));
      }
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(keys[i], style: keyTextStyle),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _HotkeyRecorderDialog extends StatefulWidget {
  const _HotkeyRecorderDialog({
    required this.initial,
  });

  final GlobalHotkeyConfig initial;

  @override
  State<_HotkeyRecorderDialog> createState() => _HotkeyRecorderDialogState();
}

class _HotkeyRecorderDialogState extends State<_HotkeyRecorderDialog> {
  final FocusNode _focusNode = FocusNode();
  GlobalHotkeyConfig? _recorded;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final keys = (_recorded ?? widget.initial).keyCaps();

    return AlertDialog(
      title: Text(l.shortcutRecorderTitle),
      content: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.shortcutRecorderHint),
            const SizedBox(height: 12),
            _ShortcutKeys(keys: keys),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red[600])),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: _recorded == null
              ? null
              : () => Navigator.of(context).pop(_recorded),
          child: Text(l.save),
        ),
      ],
    );
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return;
    }
    if (_isModifierOnly(event.logicalKey)) return;
    final config = _configFromEvent(event);
    if (config == null) return;
    setState(() {
      _recorded = config;
      _error = null;
    });
  }

  GlobalHotkeyConfig? _configFromEvent(RawKeyEvent event) {
    final l = AppLocalizations.of(context);
    final keyLabel = _normalizeKeyLabel(event.logicalKey);
    if (keyLabel == null) {
      setState(() {
        _error = l.shortcutRecorderUnsupported;
      });
      return null;
    }
    final meta = event.isMetaPressed;
    final alt = event.isAltPressed;
    final shift = event.isShiftPressed;
    final control = event.isControlPressed;
    if (!(meta || alt || shift || control)) {
      setState(() {
        _error = l.shortcutRecorderInvalid;
      });
      return null;
    }
    return GlobalHotkeyConfig(
      key: keyLabel,
      meta: meta,
      alt: alt,
      shift: shift,
      control: control,
    );
  }

  bool _isModifierOnly(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  String? _normalizeKeyLabel(LogicalKeyboardKey key) {
    final label = key.keyLabel;
    if (label.isEmpty) return null;
    if (label.length == 1) {
      final normalized = label.toUpperCase();
      final isLetter = normalized.codeUnitAt(0) >= 65 && normalized.codeUnitAt(0) <= 90;
      final isDigit = normalized.codeUnitAt(0) >= 48 && normalized.codeUnitAt(0) <= 57;
      if (isLetter || isDigit) {
        return normalized;
      }
    }
    if (label.toLowerCase() == 'space') {
      return 'Space';
    }
    return null;
  }
}
