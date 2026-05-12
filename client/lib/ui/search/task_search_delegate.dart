import 'package:flutter/material.dart';

import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/task_row.dart';

class TaskSearchEntry {
  const TaskSearchEntry({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;
}

Future<void> showTaskSearchPanel({
  required BuildContext context,
  required AppDatabase db,
  required AppLocalizations l,
  required List<TaskSearchEntry> entries,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
        alignment: Alignment.topCenter,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _TaskSearchPanel(db: db, l: l, entries: entries),
      );
    },
  );
}

class _TaskSearchPanel extends StatefulWidget {
  const _TaskSearchPanel({
    required this.db,
    required this.l,
    required this.entries,
  });

  final AppDatabase db;
  final AppLocalizations l;
  final List<TaskSearchEntry> entries;

  @override
  State<_TaskSearchPanel> createState() => _TaskSearchPanelState();
}

class _TaskSearchPanelState extends State<_TaskSearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isZh => widget.l.locale.languageCode == 'zh';

  String get _fieldHint => _isZh ? '快速查找' : 'Quick Find';

  String get _recentLabel => _isZh ? '最近' : 'Recent';

  String get _emptyHint => _isZh
      ? '快速切换列表、查找待办事项、\n搜索标签...'
      : 'Quickly switch lists, find tasks,\nand search tags...';

  void _selectEntry(TaskSearchEntry entry) {
    Navigator.of(context).pop();
    entry.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor =
        isDark ? const Color(0xFF202329) : const Color(0xFFF6F7F9);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFC8CCD3);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Material(
        color: panelColor,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(38),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: _fieldHint,
                  onChanged: (value) {
                    setState(() => _query = value.trim());
                  },
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                ),
                const SizedBox(height: 28),
                if (_query.isEmpty)
                  _RecentEntries(
                    title: _recentLabel,
                    entries: widget.entries,
                    onSelected: _selectEntry,
                    emptyHint: _emptyHint,
                  )
                else
                  _TaskResults(
                    db: widget.db,
                    l: widget.l,
                    query: _query,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE1E5ED);
    final hintColor = theme.colorScheme.onSurface.withValues(alpha: 0.42);

    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: hintColor,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(Icons.search, size: 34, color: hintColor),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                ),
          filled: true,
          fillColor: fill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _RecentEntries extends StatelessWidget {
  const _RecentEntries({
    required this.title,
    required this.entries,
    required this.onSelected,
    required this.emptyHint,
  });

  final String title;
  final List<TaskSearchEntry> entries;
  final ValueChanged<TaskSearchEntry> onSelected;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.onSurface.withValues(alpha: 0.16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 27,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.46),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Divider(height: 1, thickness: 2, color: dividerColor),
        const SizedBox(height: 15),
        ...entries.map(
          (entry) => _RecentEntryTile(
            entry: entry,
            onTap: () => onSelected(entry),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          emptyHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            height: 1.25,
            fontSize: 25,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.34),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RecentEntryTile extends StatelessWidget {
  const _RecentEntryTile({
    required this.entry,
    required this.onTap,
  });

  final TaskSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary.withValues(alpha: 0.28);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: entry.isSelected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(entry.icon, color: entry.color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (entry.isSelected) ...[
                  Icon(Icons.check, color: theme.colorScheme.primary, size: 31),
                  const SizedBox(width: 13),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskResults extends StatelessWidget {
  const _TaskResults({
    required this.db,
    required this.l,
    required this.query,
  });

  final AppDatabase db;
  final AppLocalizations l;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 430,
      child: StreamBuilder<List<Task>>(
        stream: db.watchTasksByKeyword(query),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return Center(
              child: Text(
                l.searchEmpty,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 4),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TaskRow(task: task, db: db);
            },
            separatorBuilder: (context, index) =>
                Divider(height: 1, indent: 54, color: theme.dividerColor),
            itemCount: tasks.length,
          );
        },
      ),
    );
  }
}
