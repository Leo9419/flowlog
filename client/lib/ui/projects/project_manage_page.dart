import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../database/database.dart';
import 'package:provider/provider.dart';
import '../../theme/color_utils.dart';
import '../widgets/color_picker_sheet.dart';

class ProjectManagePage extends StatelessWidget {
  const ProjectManagePage({super.key});

  Future<void> _showProjectDialog(
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
    Project project,
    AppDatabase db,
  ) async {
    final l = AppLocalizations.of(context);
    await _showProjectDialog(
      context,
      title: l.renameProject,
      confirmLabel: l.save,
      initialName: project.name,
      initialColor: hexToColor(project.color),
      onConfirm: (name, color) {
        db.updateProject(project.id, name, colorToHex(color));
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, AppDatabase db) async {
    final l = AppLocalizations.of(context);
    await _showProjectDialog(
      context,
      title: l.addProject,
      confirmLabel: l.add,
      onConfirm: (name, color) => db.createProject(name, colorToHex(color)),
    );
  }

  Future<void> _changeColor(
    BuildContext context,
    Project project,
    AppDatabase db,
  ) async {
    final color = await showColorPickerSheet(context, selected: hexToColor(project.color));
    if (color != null) {
      await db.updateProject(project.id, project.name, colorToHex(color));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.manageProjects),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context, db),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: db.watchProjects(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final projects = snapshot.data!;
          if (projects.isEmpty) {
            return Center(
              child: Text(
                l.projectListEmpty,
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: hexToColor(project.color),
                ),
                title: Text(project.name),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'rename':
                        await _showRenameDialog(context, project, db);
                        break;
                      case 'color':
                        await _changeColor(context, project, db);
                        break;
                      case 'delete':
                        await db.deleteProject(project.id);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l.renameProject),
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
              );
            },
          );
        },
      ),
    );
  }
}
