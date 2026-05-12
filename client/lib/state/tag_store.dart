import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TagItem {
  TagItem({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  String name;
  Color color;
}

class TagStore extends ChangeNotifier {
  TagStore()
      : _tags = [
          TagItem(
            id: 'tag-work',
            name: 'Work',
            color: Colors.blue,
          ),
          TagItem(
            id: 'tag-life',
            name: 'Life',
            color: Colors.orange,
          ),
        ];

  final List<TagItem> _tags;

  List<TagItem> get tags => List.unmodifiable(_tags);

  TagItem? getById(String id) {
    for (final tag in _tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  void addTag(String name, Color color) {
    final id = const Uuid().v4();
    _tags.add(TagItem(id: id, name: name, color: color));
    notifyListeners();
  }

  void renameTag(String id, String name) {
    final tag = getById(id);
    if (tag == null) return;
    tag.name = name;
    notifyListeners();
  }

  void changeColor(String id, Color color) {
    final tag = getById(id);
    if (tag == null) return;
    tag.color = color;
    notifyListeners();
  }

  void deleteTag(String id) {
    _tags.removeWhere((tag) => tag.id == id);
    notifyListeners();
  }
}
