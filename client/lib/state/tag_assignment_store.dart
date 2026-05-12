import 'package:flutter/material.dart';

class TagAssignmentStore extends ChangeNotifier {
  final Map<String, Set<String>> _taskTags = {};

  Set<String> tagsForTask(String taskId) {
    final tags = _taskTags[taskId];
    return tags == null ? <String>{} : Set<String>.from(tags);
  }

  bool hasTag(String taskId, String tagId) {
    return _taskTags[taskId]?.contains(tagId) ?? false;
  }

  void setTagsForTask(String taskId, Set<String> tagIds) {
    _taskTags[taskId] = Set<String>.from(tagIds);
    notifyListeners();
  }

  void toggleTag(String taskId, String tagId) {
    final tags = _taskTags.putIfAbsent(taskId, () => <String>{});
    if (tags.contains(tagId)) {
      tags.remove(tagId);
    } else {
      tags.add(tagId);
    }
    notifyListeners();
  }

  void clearTask(String taskId) {
    if (_taskTags.remove(taskId) != null) {
      notifyListeners();
    }
  }

  int countForTag(String tagId) {
    var count = 0;
    for (final tags in _taskTags.values) {
      if (tags.contains(tagId)) {
        count += 1;
      }
    }
    return count;
  }
}
