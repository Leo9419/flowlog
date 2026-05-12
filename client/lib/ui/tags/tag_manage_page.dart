import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database.dart';
import 'package:provider/provider.dart';
import '../widgets/color_picker_sheet.dart';

class TagManagePage extends StatelessWidget {
  const TagManagePage({super.key});

  Future<void> _showTagDialog(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialName = '',
    Color? initialColor,
    required void Function(String name, Color color) onConfirm,
  }) async {
    final controller = TextEditingController(text: initialName);
    var selectedColor = initialColor ?? kPresetColors.first;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kPresetColors.map((color) {
                      final isSelected = selectedColor.value == color.value;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedColor = color;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? Colors.black87 : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                TextButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    onConfirm(name, selectedColor);
                    Navigator.of(context).pop();
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    Tag tag,
    AppDatabase db,
  ) async {
    final l = AppLocalizations.of(context);
    await _showTagDialog(
      context,
      title: l.renameTag,
      confirmLabel: l.save,
      initialName: tag.name,
      initialColor: Color(tag.color),
      onConfirm: (name, color) {
        db.updateTag(tag.id, name, color.value);
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, AppDatabase db) async {
    final l = AppLocalizations.of(context);
    await _showTagDialog(
      context,
      title: l.addTag,
      confirmLabel: l.add,
      onConfirm: (name, color) => db.createTag(name, color.value),
    );
  }

  Future<void> _changeColor(
    BuildContext context,
    Tag tag,
    AppDatabase db,
  ) async {
    final color = await showColorPickerSheet(context, selected: Color(tag.color));
    if (color != null) {
      await db.updateTag(tag.id, tag.name, color.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.manageTags),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context, db),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Tag>>(
        stream: db.watchTags(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tags = snapshot.data!;
          if (tags.isEmpty) {
            return Center(
              child: Text(
                l.tagListEmpty,
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ReorderableListView.builder(
            itemCount: tags.length,
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final reordered = List<Tag>.from(tags);
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              await db.updateTagSortOrders(
                reordered.map((tag) => tag.id).toList(),
              );
            },
            itemBuilder: (context, index) {
              final tag = tags[index];
              return Container(
                key: ValueKey(tag.id),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(tag.color),
                  ),
                  title: Text(tag.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'rename':
                              await _showRenameDialog(context, tag, db);
                              break;
                            case 'color':
                              await _changeColor(context, tag, db);
                              break;
                            case 'delete':
                              await db.deleteTag(tag.id);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(l.renameTag),
                          ),
                          PopupMenuItem(
                            value: 'color',
                            child: Text(l.changeColor),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l.delete),
                          ),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle, size: 20),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
