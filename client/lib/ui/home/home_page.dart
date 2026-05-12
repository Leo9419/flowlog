import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../database/database.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ai_local_service.dart';
import '../../services/ai_cloud_service.dart';
import '../../state/app_commands.dart';
import '../../state/app_settings.dart';
import '../../theme/color_utils.dart';
import '../today/today_page.dart';
import '../inbox/inbox_page.dart';
import '../profile/profile_page.dart';
import '../projects/project_page.dart';
import '../projects/project_manage_page.dart';
import '../search/task_search_delegate.dart';
import '../settings/settings_page.dart';
import '../task_sort.dart';
import '../trash/trash_page.dart';
import '../tags/tag_manage_page.dart';
import '../tags/tag_page.dart';
import '../upcoming/upcoming_page.dart';
import '../widgets/color_picker_sheet.dart';
import '../ai/ai_chat_page.dart';

class QuickAddIntent extends Intent {
  const QuickAddIntent(this.target);

  final QuickAddTarget target;
}

enum _QuickAddAction { add, ai, image }

class _QuickAddResult {
  const _QuickAddResult(this.action, this.text);

  final _QuickAddAction action;
  final String text;
}

class NavigateIntent extends Intent {
  const NavigateIntent(this.index);

  final int index;
}

class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class CloseOverlayIntent extends Intent {
  const CloseOverlayIntent();
}

/// 旧版顶层页面，M1_04 起被 [AdaptiveShell] 取代。
///
/// 仅保留作为回滚兜底；M2 视图重构期间需要参考其中的 AI 入口、Tags
/// 区、命令面板等子功能怎么实装到新 Shell。M2 完成后从仓库移除。
@Deprecated(
  'Replaced by AdaptiveShell in M1_04; will be removed at the end of M2.',
)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  TaskSortMode _sortMode = TaskSortMode.createdDesc;
  bool _upcomingPopupShown = false;
  StreamSubscription<QuickAddTarget>? _quickAddSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowUpcomingPopup();
      _bindCommandBus();
    });
  }

  @override
  void dispose() {
    _quickAddSubscription?.cancel();
    super.dispose();
  }

  QuickAddTarget _resolveQuickAddTarget(QuickAddTarget target) {
    if (target != QuickAddTarget.current) {
      return target;
    }
    if (_currentIndex == 0) {
      return QuickAddTarget.today;
    }
    if (_currentIndex == 1) {
      return QuickAddTarget.inbox;
    }
    return QuickAddTarget.inbox;
  }

  Future<void> _showQuickAddDialog(
      {QuickAddTarget target = QuickAddTarget.current}) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final settings = Provider.of<AppSettings>(context, listen: false);
    final l = AppLocalizations.of(context);
    final resolvedTarget = _resolveQuickAddTarget(target);
    final now = DateTime.now();
    final dueDate = resolvedTarget == QuickAddTarget.today
        ? DateTime(now.year, now.month, now.day)
        : null;
    final dialogTitle =
        resolvedTarget == QuickAddTarget.today ? l.today : l.inbox;
    final hintText = resolvedTarget == QuickAddTarget.today
        ? l.addTaskToToday
        : l.inboxTaskTitle;

    final result = await showDialog<_QuickAddResult>(
      context: context,
      builder: (context) {
        return _QuickAddDialog(
          title: dialogTitle,
          hintText: hintText,
          showAi: settings.aiProvider == AiProviderType.local ||
              settings.aiProvider == AiProviderType.cloud,
          showImage: settings.aiProvider == AiProviderType.cloud,
          aiLabel: l.aiQuickAdd,
          imageLabel: l.aiImageAdd,
          addLabel: l.add,
          cancelLabel: l.cancel,
        );
      },
    );

    if (!mounted || result == null) return;
    final input = result.text.trim();
    if (result.action == _QuickAddAction.add) {
      if (input.isEmpty) return;

      final newTask = TasksCompanion(
        id: drift.Value(const Uuid().v4()),
        title: drift.Value(input),
        status: const drift.Value(0),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
        dueDate: drift.Value(dueDate),
        isAllDay: drift.Value(dueDate != null),
      );

      await db.insertTask(newTask);
    } else if (result.action == _QuickAddAction.ai) {
      await _handleAiQuickAdd(
        input: input,
        target: resolvedTarget,
        db: db,
      );
    } else if (result.action == _QuickAddAction.image) {
      await _handleAiImageQuickAdd(
        hint: input,
        target: resolvedTarget,
        db: db,
      );
    }
  }

  Future<void> _handleAiQuickAdd({
    required String input,
    required QuickAddTarget target,
    required AppDatabase db,
  }) async {
    final l = AppLocalizations.of(context);
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiQuickAddNoInput)),
      );
      return;
    }

    final settings = Provider.of<AppSettings>(context, listen: false);
    Future<AiQuickAddDraft> Function() request;
    String missingConfigMessage;
    if (settings.aiProvider == AiProviderType.cloud) {
      if (settings.aiCloudEndpoint.trim().isEmpty ||
          settings.aiCloudApiKey.trim().isEmpty ||
          settings.aiCloudModel.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.aiCloudConfigMissing)),
        );
        return;
      }
      final aiService = Provider.of<AiCloudService>(context, listen: false);
      request = () => aiService.parseQuickAdd(
            input: input,
            now: DateTime.now(),
          );
      missingConfigMessage = l.aiCloudConfigMissing;
    } else {
      if (settings.aiLocalEndpoint.trim().isEmpty ||
          settings.aiLocalModel.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.aiLocalConfigMissing)),
        );
        return;
      }
      final aiService = Provider.of<AiLocalService>(context, listen: false);
      request = () => aiService.parseQuickAdd(
            input: input,
            now: DateTime.now(),
          );
      missingConfigMessage = l.aiLocalConfigMissing;
    }

    final draft = await _requestAiQuickAddDraft(
      request: request,
      missingConfigMessage: missingConfigMessage,
    );
    if (!mounted || draft == null) return;

    final resolvedDraft = _applyAiQuickAddDefaults(draft, target);
    final enrichedDraft = await _mergeTagsFromInputWithKnownTags(
      db: db,
      draft: resolvedDraft,
      input: input,
    );
    final confirmed = await _confirmAiQuickAdd(enrichedDraft);
    if (!confirmed || !mounted) return;

    final now = DateTime.now();
    final taskId = const Uuid().v4();
    final drift.Value<String?> contentValue = enrichedDraft.notes == null
        ? const drift.Value<String?>.absent()
        : drift.Value(enrichedDraft.notes);
    final newTask = TasksCompanion(
      id: drift.Value(taskId),
      title: drift.Value(enrichedDraft.title),
      content: contentValue,
      status: const drift.Value(0),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
      dueDate: drift.Value(enrichedDraft.dueDate),
      endDate: drift.Value(enrichedDraft.endDate),
      isAllDay: drift.Value(
        enrichedDraft.dueDate != null && enrichedDraft.isAllDay,
      ),
    );

    await db.insertTask(newTask);
    await _assignTagsForTask(
      db: db,
      taskId: taskId,
      tagNames: enrichedDraft.tags,
    );
  }

  Future<void> _handleAiImageQuickAdd({
    required String hint,
    required QuickAddTarget target,
    required AppDatabase db,
  }) async {
    final l = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (settings.aiProvider != AiProviderType.cloud) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiImageCloudOnly)),
      );
      return;
    }
    if (settings.aiCloudEndpoint.trim().isEmpty ||
        settings.aiCloudApiKey.trim().isEmpty ||
        settings.aiCloudModel.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.aiCloudConfigMissing)),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    final path = file.path;
    if (bytes == null && path == null) {
      if (!mounted) return;
      await _showCopyableErrorDialog(l.aiImageInvalid);
      return;
    }
    final imageBytes = bytes ?? await File(path!).readAsBytes();
    final mimeType = _guessImageMime(file.name);

    final aiService = Provider.of<AiCloudService>(context, listen: false);
    final draft = await _requestAiQuickAddDraft(
      request: () => aiService.parseQuickAddFromImage(
        imageBytes: imageBytes,
        now: DateTime.now(),
        hint: hint.trim().isEmpty ? null : hint.trim(),
        mimeType: mimeType,
      ),
      missingConfigMessage: l.aiCloudConfigMissing,
    );
    if (!mounted || draft == null) return;

    final resolvedDraft = _applyAiQuickAddDefaults(draft, target);
    final enrichedDraft = await _mergeTagsFromInputWithKnownTags(
      db: db,
      draft: resolvedDraft,
      input: hint,
    );
    final confirmed = await _confirmAiQuickAdd(enrichedDraft);
    if (!confirmed || !mounted) return;

    final now = DateTime.now();
    final taskId = const Uuid().v4();
    final drift.Value<String?> contentValue = enrichedDraft.notes == null
        ? const drift.Value<String?>.absent()
        : drift.Value(enrichedDraft.notes);
    final newTask = TasksCompanion(
      id: drift.Value(taskId),
      title: drift.Value(enrichedDraft.title),
      content: contentValue,
      status: const drift.Value(0),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
      dueDate: drift.Value(enrichedDraft.dueDate),
      endDate: drift.Value(enrichedDraft.endDate),
      isAllDay: drift.Value(
        enrichedDraft.dueDate != null && enrichedDraft.isAllDay,
      ),
    );

    await db.insertTask(newTask);
    await _assignTagsForTask(
      db: db,
      taskId: taskId,
      tagNames: enrichedDraft.tags,
    );
  }

  Future<AiQuickAddDraft?> _requestAiQuickAddDraft({
    required Future<AiQuickAddDraft> Function() request,
    required String missingConfigMessage,
  }) async {
    final l = AppLocalizations.of(context);
    if (!mounted) return null;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(l.aiQuickAddParsing),
            ],
          ),
        );
      },
    );

    AiQuickAddDraft? draft;
    String? errorMessage;
    try {
      draft = await request();
    } on FormatException catch (error) {
      if (error.message == 'missing_config') {
        errorMessage = missingConfigMessage;
      } else if (error.message.isNotEmpty) {
        errorMessage = l.aiQuickAddFailedWithReason(error.message);
      } else {
        errorMessage = l.aiQuickAddFailed;
      }
    } catch (_) {
      errorMessage = l.aiQuickAddFailed;
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (errorMessage != null && mounted) {
      await _showCopyableErrorDialog(errorMessage);
    }
    return draft;
  }

  AiQuickAddDraft _applyAiQuickAddDefaults(
    AiQuickAddDraft draft,
    QuickAddTarget target,
  ) {
    var dueDate = draft.dueDate;
    var isAllDay = draft.isAllDay;

    if (dueDate == null && target == QuickAddTarget.today) {
      final now = DateTime.now();
      dueDate = DateTime(now.year, now.month, now.day);
      isAllDay = true;
    }

    if (dueDate != null) {
      final isDateOnly = dueDate.hour == 0 &&
          dueDate.minute == 0 &&
          dueDate.second == 0 &&
          dueDate.millisecond == 0 &&
          dueDate.microsecond == 0;
      if (isDateOnly) {
        isAllDay = true;
      }
      if (isAllDay) {
        dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      }
    } else {
      isAllDay = false;
    }

    return draft.copyWith(dueDate: dueDate, isAllDay: isAllDay);
  }

  Future<bool> _confirmAiQuickAdd(AiQuickAddDraft draft) async {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dueLabel = draft.dueDate == null
        ? l.noDueDate
        : _formatDraftDueLabel(draft.dueDate!, draft.isAllDay);
    final endLabel = draft.endDate == null
        ? l.noEndDate
        : _formatDraftDueLabel(draft.endDate!, false);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l.aiQuickAddPreview),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.title,
                style: theme.textTheme.titleMedium,
              ),
              if (draft.notes != null) ...[
                const SizedBox(height: 8),
                Text(draft.notes!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text('${l.dueDate} $dueLabel',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text('${l.endDate} $endLabel',
                      style: theme.textTheme.bodySmall),
                ],
              ),
              if (draft.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: draft.tags
                      .map(
                        (tag) => Chip(
                          label:
                              Text('#$tag', style: theme.textTheme.labelSmall),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.add),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  String _formatDraftDueLabel(DateTime dueDate, bool isAllDay) {
    final isDateOnly = dueDate.hour == 0 &&
        dueDate.minute == 0 &&
        dueDate.second == 0 &&
        dueDate.millisecond == 0 &&
        dueDate.microsecond == 0;
    final showTime = !(isAllDay || isDateOnly);
    final dateText =
        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    if (!showTime) {
      return dateText;
    }
    final timeText =
        '${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}';
    return '$dateText $timeText';
  }

  Future<void> _assignTagsForTask({
    required AppDatabase db,
    required String taskId,
    required List<String> tagNames,
  }) async {
    if (tagNames.isEmpty) return;
    final tags = await db.select(db.tags).get();
    final nameToId = <String, String>{
      for (final tag in tags) tag.name.toLowerCase(): tag.id,
    };
    final tagIds = <String>{};
    var colorIndex = tags.length;

    for (final raw in tagNames) {
      final name = _normalizeTagName(raw);
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final existingId = nameToId[key];
      if (existingId != null) {
        tagIds.add(existingId);
        continue;
      }
      final color = kPresetColors[colorIndex % kPresetColors.length].value;
      colorIndex += 1;
      final newId = await db.createTag(name, color);
      nameToId[key] = newId;
      tagIds.add(newId);
    }

    if (tagIds.isNotEmpty) {
      await db.setTagsForTask(taskId, tagIds);
    }
  }

  Future<AiQuickAddDraft> _mergeTagsFromInputWithKnownTags({
    required AppDatabase db,
    required AiQuickAddDraft draft,
    required String input,
  }) async {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return draft;

    final tags = await db.select(db.tags).get();
    if (tags.isEmpty) return draft;

    final inputLower = trimmedInput.toLowerCase();
    final matched = <String>[];
    for (final tag in tags) {
      final name = _normalizeTagName(tag.name);
      if (name.isEmpty) continue;
      if (_containsTagToken(inputLower, name.toLowerCase())) {
        matched.add(name);
      }
    }

    if (matched.isEmpty) return draft;
    return draft.copyWith(tags: _mergeTagNames(matched, draft.tags));
  }

  String _normalizeTagName(String value) {
    var name = value.trim();
    name = name.replaceAll(RegExp(r'^[#@]+'), '');
    return name.trim();
  }

  List<String> _mergeTagNames(List<String> primary, List<String> secondary) {
    final seen = <String>{};
    final merged = <String>[];
    for (final tag in [...primary, ...secondary]) {
      final normalized = _normalizeTagName(tag);
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        merged.add(normalized);
      }
    }
    return merged;
  }

  bool _containsTagToken(String inputLower, String tagLower) {
    var start = 0;
    while (true) {
      final index = inputLower.indexOf(tagLower, start);
      if (index == -1) return false;
      final beforeOk = index == 0 || _isTagBoundary(inputLower[index - 1]);
      final afterIndex = index + tagLower.length;
      final afterOk = afterIndex >= inputLower.length ||
          _isTagBoundary(inputLower[afterIndex]);
      if (beforeOk && afterOk) return true;
      start = index + 1;
    }
  }

  bool _isTagBoundary(String ch) {
    return !_isAsciiWordChar(ch);
  }

  bool _isAsciiWordChar(String ch) {
    return RegExp(r'[A-Za-z0-9_]').hasMatch(ch);
  }

  String _guessImageMime(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/png';
  }

  Future<void> _showCopyableErrorDialog(String message) async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l.errorDetails),
          content: SelectableText(message),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.copied)),
                );
              },
              child: Text(l.copy),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _maybeShowUpcomingPopup() async {
    if (_upcomingPopupShown || !mounted) return;
    final settings = Provider.of<AppSettings>(context, listen: false);
    if (settings.upcomingPopupLastShown != null) {
      _upcomingPopupShown = true;
      return;
    }
    final now = DateTime.now();
    if (!settings.notificationsEnabled || !settings.upcomingReminderEnabled) {
      _upcomingPopupShown = true;
      return;
    }
    final db = Provider.of<AppDatabase>(context, listen: false);
    final tasks = await db.watchNotifiableTasks().first;
    final windowEnd = now.add(const Duration(hours: 24));

    final upcomingTasks = <Task>[];
    for (final task in tasks) {
      final dueDate = task.dueDate;
      if (dueDate == null) continue;
      final normalizedDue = _normalizeDueDate(task);
      if (!normalizedDue.isBefore(now) && normalizedDue.isBefore(windowEnd)) {
        upcomingTasks.add(task);
      }
    }

    if (upcomingTasks.isEmpty) {
      _upcomingPopupShown = true;
      return;
    }

    upcomingTasks
        .sort((a, b) => _normalizeDueDate(a).compareTo(_normalizeDueDate(b)));
    _upcomingPopupShown = true;

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final summary = l.upcomingSummaryNotificationBody(upcomingTasks.length);
    final listHeight = upcomingTasks.length * 56.0;
    final constrainedHeight =
        listHeight < 56.0 ? 56.0 : (listHeight > 280.0 ? 280.0 : listHeight);

    final goUpcoming = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l.upcomingSummaryNotificationTitle),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary),
                const SizedBox(height: 12),
                SizedBox(
                  height: constrainedHeight,
                  child: ListView.separated(
                    itemCount: upcomingTasks.length,
                    itemBuilder: (context, index) {
                      final task = upcomingTasks[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(task.title),
                        subtitle: Text(_formatDueLabel(task)),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.upcoming),
            ),
          ],
        );
      },
    );

    await settings.setUpcomingPopupLastShown(now);
    if (goUpcoming == true && mounted) {
      setState(() {
        _currentIndex = 2;
      });
    }
  }

  void _bindCommandBus() {
    final commands = Provider.of<AppCommandBus>(context, listen: false);
    _quickAddSubscription = commands.quickAddStream.listen((target) {
      if (!mounted) return;
      _showQuickAddDialog(target: target);
    });
  }

  DateTime _normalizeDueDate(Task task) {
    final dueDate = task.dueDate!;
    final isDateOnly = dueDate.hour == 0 &&
        dueDate.minute == 0 &&
        dueDate.second == 0 &&
        dueDate.millisecond == 0 &&
        dueDate.microsecond == 0;
    if (task.isAllDay || isDateOnly) {
      return DateTime(dueDate.year, dueDate.month, dueDate.day, 17);
    }
    return dueDate;
  }

  String _formatDueLabel(Task task) {
    final dueDate = task.dueDate;
    if (dueDate == null) return '';
    final isDateOnly = dueDate.hour == 0 &&
        dueDate.minute == 0 &&
        dueDate.second == 0 &&
        dueDate.millisecond == 0 &&
        dueDate.microsecond == 0;
    final showTime = !(task.isAllDay || isDateOnly);
    final dateText =
        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
    if (!showTime) {
      return dateText;
    }
    final timeText =
        '${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}';
    return '$dateText $timeText';
  }

  Future<void> _openSearch(AppDatabase db) async {
    final l = AppLocalizations.of(context);
    await showTaskSearchPanel(
      context: context,
      db: db,
      l: l,
      entries: [
        TaskSearchEntry(
          icon: Icons.star,
          label: l.today,
          color: const Color(0xFFE8B000),
          isSelected: _currentIndex == 0,
          onTap: () => setState(() => _currentIndex = 0),
        ),
        TaskSearchEntry(
          icon: Icons.delete,
          label: l.trash,
          color: const Color(0xFFAEB4BC),
          onTap: _openTrash,
        ),
        TaskSearchEntry(
          icon: Icons.layers,
          label: _taskBoxLabel(context, l),
          color: const Color(0xFF2FA7A0),
          isSelected: _currentIndex == 1,
          onTap: () => setState(() => _currentIndex = 1),
        ),
        TaskSearchEntry(
          icon: Icons.calendar_month,
          label: _planLabel(context, l),
          color: const Color(0xFFFF3B6B),
          isSelected: _currentIndex == 2,
          onTap: () => setState(() => _currentIndex = 2),
        ),
        TaskSearchEntry(
          icon: Icons.chat_bubble,
          label: l.aiChat,
          color: const Color(0xFF7B61FF),
          isSelected: _currentIndex == 3,
          onTap: () => setState(() => _currentIndex = 3),
        ),
      ],
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrashPage()),
    );
  }

  void _openProject(String projectId, String projectName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectPage(
          projectId: projectId,
          projectName: projectName,
          sortMode: _sortMode,
        ),
      ),
    );
  }

  void _openProjectManager() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProjectManagePage()),
    );
  }

  void _openTagManager() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TagManagePage()),
    );
  }

  void _openTag(String tagId, String tagName, Color color) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TagPage(
          tagId: tagId,
          tagName: tagName,
          color: color,
          sortMode: _sortMode,
        ),
      ),
    );
  }

  void _showCommandPalette() {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.commandPaletteComingSoon)),
    );
  }

  Future<void> _closeOverlay() async {
    final navigator = Navigator.of(context);
    final didPop = await navigator.maybePop();
    if (!didPop) {
      FocusScope.of(context).unfocus();
    }
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const QuickAddIntent(QuickAddTarget.current),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
          const QuickAddIntent(QuickAddTarget.inbox),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true, alt: true):
          const QuickAddIntent(QuickAddTarget.today),
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
          const OpenSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
          const NavigateIntent(0),
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
          const NavigateIntent(1),
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
          const NavigateIntent(2),
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
          const NavigateIntent(3),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          const OpenCommandPaletteIntent(),
      const SingleActivator(LogicalKeyboardKey.escape):
          const CloseOverlayIntent(),
    };
  }

  Map<Type, Action<Intent>> _buildActions(AppDatabase db) {
    return <Type, Action<Intent>>{
      QuickAddIntent: CallbackAction<QuickAddIntent>(
        onInvoke: (intent) {
          _showQuickAddDialog(target: intent.target);
          return null;
        },
      ),
      OpenSearchIntent: CallbackAction<OpenSearchIntent>(
        onInvoke: (_) {
          _openSearch(db);
          return null;
        },
      ),
      NavigateIntent: CallbackAction<NavigateIntent>(
        onInvoke: (intent) {
          if (intent.index != _currentIndex) {
            setState(() {
              _currentIndex = intent.index;
            });
          }
          return null;
        },
      ),
      OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
        onInvoke: (_) {
          _showCommandPalette();
          return null;
        },
      ),
      CloseOverlayIntent: CallbackAction<CloseOverlayIntent>(
        onInvoke: (_) {
          _closeOverlay();
          return null;
        },
      ),
    };
  }

  bool _isZh(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'zh';
  }

  String _planLabel(BuildContext context, AppLocalizations l) {
    return l.calendar;
  }

  String _taskBoxLabel(BuildContext context, AppLocalizations l) {
    return _isZh(context) ? '任务箱' : l.inbox;
  }

  String _newListLabel(BuildContext context) {
    return _isZh(context) ? '新建列表' : 'New List';
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: _buildActions(db),
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 简单阈值判断，> 600 视为桌面/平板宽屏模式
              if (constraints.maxWidth > 600) {
                return _buildDesktopLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final l = AppLocalizations.of(context);
    final db = Provider.of<AppDatabase>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarColor =
        isDark ? theme.colorScheme.surface : const Color(0xFFF4F5F7);

    return Scaffold(
      body: Row(
        children: [
          // Custom Sidebar
          Container(
            width: 264,
            decoration: BoxDecoration(
              color: sidebarColor,
              border: Border(
                right: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: TextField(
                      readOnly: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      onTap: () => _openSearch(db),
                      decoration: InputDecoration(
                        hintText: l.searchTasks,
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor:
                            Colors.white.withOpacity(isDark ? 0.04 : 0.72),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        StreamBuilder<List<Task>>(
                          stream: db.watchTodayTasks(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length;
                            return _SidebarItem(
                              icon: Icons.wb_sunny_outlined,
                              activeIcon: Icons.wb_sunny,
                              label: l.today,
                              isSelected: _currentIndex == 0,
                              onTap: () => setState(() => _currentIndex = 0),
                              count: count,
                            );
                          },
                        ),
                        _SidebarItem(
                          icon: Icons.calendar_month_outlined,
                          activeIcon: Icons.calendar_month,
                          label: _planLabel(context, l),
                          isSelected: _currentIndex == 2,
                          onTap: () => setState(() => _currentIndex = 2),
                          color: const Color(0xFFFF3B6B),
                        ),
                        StreamBuilder<List<Task>>(
                          stream: db.watchInboxTasks(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length;
                            return _SidebarItem(
                              icon: Icons.layers_outlined,
                              activeIcon: Icons.layers,
                              label: _taskBoxLabel(context, l),
                              isSelected: _currentIndex == 1,
                              onTap: () => setState(() => _currentIndex = 1),
                              count: count,
                              color: const Color(0xFF2FA7A0),
                            );
                          },
                        ),
                        _SidebarItem(
                          icon: Icons.delete_outline,
                          activeIcon: Icons.delete,
                          label: l.trash,
                          isSelected: false,
                          onTap: _openTrash,
                          color: const Color(0xFFAEB4BC),
                        ),
                        _SidebarItem(
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble,
                          label: l.aiChat,
                          isSelected: _currentIndex == 3,
                          onTap: () => setState(() => _currentIndex = 3),
                          color: const Color(0xFF7B61FF),
                        ),
                        const Divider(height: 24),
                        _SidebarSectionHeader(
                          title: l.lists,
                          onAdd: _openProjectManager,
                          addTooltip: l.manageProjects,
                        ),
                        StreamBuilder<List<Project>>(
                          stream: db.watchProjects(),
                          builder: (context, snapshot) {
                            final projects = snapshot.data ?? const <Project>[];
                            if (projects.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: projects
                                  .map(
                                    (project) => _SidebarItem(
                                      icon: Icons.list,
                                      label: project.name,
                                      isSelected: false,
                                      onTap: () => _openProject(
                                          project.id, project.name),
                                      color: hexToColor(project.color),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        const Divider(height: 24),
                        _SidebarSectionHeader(
                          title: l.tags,
                          onAdd: _openTagManager,
                          addTooltip: l.manageTags,
                        ),
                        StreamBuilder<List<Tag>>(
                          stream: db.watchTags(),
                          builder: (context, snapshot) {
                            final tags = snapshot.data ?? const <Tag>[];
                            if (tags.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: tags
                                  .map(
                                    (tag) => _SidebarItem(
                                      icon: Icons.label_outline,
                                      label: tag.name,
                                      isSelected: false,
                                      onTap: () => _openTag(
                                          tag.id, tag.name, Color(tag.color)),
                                      color: Color(tag.color),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Bottom Actions
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: sidebarColor,
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _openProjectManager,
                            icon: const Icon(Icons.add, size: 22),
                            tooltip: _newListLabel(context),
                          ),
                          Text(
                            _newListLabel(context),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.tune, size: 22),
                            tooltip: l.settings,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: [
                  TodayPage(sortMode: _sortMode),
                  InboxPage(sortMode: _sortMode),
                  UpcomingPage(sortMode: _sortMode),
                  const AiChatPage(),
                  const ProfilePage(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    final l = AppLocalizations.of(context);
    final db = Provider.of<AppDatabase>(context);

    final titles = [
      l.today,
      _taskBoxLabel(context, l),
      _planLabel(context, l),
      l.aiChat,
      l.profile,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _openSearch(db),
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton<TaskSortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (mode) {
              setState(() {
                _sortMode = mode;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TaskSortMode.createdDesc,
                child: Text(l.sortByCreated),
              ),
              PopupMenuItem(
                value: TaskSortMode.dueDateAsc,
                child: Text(l.sortByDueDate),
              ),
              PopupMenuItem(
                value: TaskSortMode.priorityDesc,
                child: Text(l.sortByPriority),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TodayPage(sortMode: _sortMode),
          InboxPage(sortMode: _sortMode),
          UpcomingPage(sortMode: _sortMode),
          const AiChatPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.today_outlined),
            activeIcon: const Icon(Icons.today),
            label: titles[0],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inbox_outlined),
            activeIcon: const Icon(Icons.inbox),
            label: titles[1],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.upcoming_outlined),
            activeIcon: const Icon(Icons.upcoming),
            label: titles[2],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: titles[3],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: titles[4],
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showQuickAddDialog(
                target: _currentIndex == 0
                    ? QuickAddTarget.today
                    : QuickAddTarget.inbox,
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog({
    required this.title,
    required this.hintText,
    required this.showAi,
    required this.showImage,
    required this.aiLabel,
    required this.imageLabel,
    required this.addLabel,
    required this.cancelLabel,
  });

  final String title;
  final String hintText;
  final bool showAi;
  final bool showImage;
  final String aiLabel;
  final String imageLabel;
  final String addLabel;
  final String cancelLabel;

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(_QuickAddAction action) {
    Navigator.of(context).pop(_QuickAddResult(action, _controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
        ),
        onSubmitted: (_) => _submit(_QuickAddAction.add),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        if (widget.showAi)
          TextButton(
            onPressed: () => _submit(_QuickAddAction.ai),
            child: Text(widget.aiLabel),
          ),
        if (widget.showImage)
          TextButton(
            onPressed: () => _submit(_QuickAddAction.image),
            child: Text(widget.imageLabel),
          ),
        TextButton(
          onPressed: () => _submit(_QuickAddAction.add),
          child: Text(widget.addLabel),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  const _SidebarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.colorScheme.primary;
    final iconColor = color ??
        (isSelected ? accentColor : theme.colorScheme.onSurfaceVariant);
    final bgColor = isSelected ? const Color(0xFFDADDE3) : Colors.transparent;
    final textStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
      color: theme.colorScheme.onSurface.withOpacity(isSelected ? 0.95 : 0.88),
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    final countBackground = Colors.transparent;
    final countColor = theme.colorScheme.onSurface.withOpacity(0.52);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: theme.colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected && activeIcon != null ? activeIcon : icon,
                size: 21,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: textStyle)),
              if (count != null && count! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: countBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: countColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({
    required this.title,
    this.onAdd,
    this.addTooltip,
  });

  final String title;
  final VoidCallback? onAdd;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final displayTitle =
        locale.languageCode == 'en' ? title.toUpperCase() : title;
    final labelColor = theme.colorScheme.onSurface.withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayTitle,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          if (onAdd != null)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              tooltip: addTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              color: labelColor,
            ),
        ],
      ),
    );
  }
}
