import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ProjectItem {
  ProjectItem({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  String name;
  Color color;
}

class ProjectStore extends ChangeNotifier {
  ProjectStore()
      : _projects = [
          ProjectItem(
            id: 'work',
            name: 'Work',
            color: Colors.blue,
          ),
          ProjectItem(
            id: 'personal',
            name: 'Personal',
            color: Colors.green,
          ),
        ];

  final List<ProjectItem> _projects;

  List<ProjectItem> get projects => List.unmodifiable(_projects);

  ProjectItem? getById(String id) {
    for (final project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  void addProject(String name, Color color) {
    final id = const Uuid().v4();
    _projects.add(ProjectItem(id: id, name: name, color: color));
    notifyListeners();
  }

  void renameProject(String id, String name) {
    final project = getById(id);
    if (project == null) return;
    project.name = name;
    notifyListeners();
  }

  void changeColor(String id, Color color) {
    final project = getById(id);
    if (project == null) return;
    project.color = color;
    notifyListeners();
  }

  void deleteProject(String id) {
    _projects.removeWhere((project) => project.id == id);
    notifyListeners();
  }
}
