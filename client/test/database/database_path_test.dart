import 'dart:io';

import 'package:flowlog_client/database/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('database file resolution', () {
    test('uses Application Support as the stable primary database location',
        () async {
      final root = await Directory.systemTemp.createTemp('flowlog_db_path_');
      addTearDown(() => root.delete(recursive: true));
      final appSupport = Directory('${root.path}/support');
      final documents = Directory('${root.path}/documents');

      final file = await resolveFlowLogDatabaseFileForTesting(
        appSupportDirectory: appSupport,
        documentsDirectory: documents,
        homeDirectory: root.path,
      );

      expect(file.path, '${appSupport.path}/FlowLog/flowlog.sqlite');
      expect(file.parent.existsSync(), isTrue);
    });

    test('copies the newest legacy container database on first launch',
        () async {
      final root = await Directory.systemTemp.createTemp('flowlog_db_path_');
      addTearDown(() => root.delete(recursive: true));
      final appSupport = Directory('${root.path}/support');
      final documents = Directory('${root.path}/documents');
      final legacyOld = File(
        '${root.path}/Library/Containers/com.example.flowlogClient/Data/Documents/flowlog.sqlite',
      );
      final legacyNew = File(
        '${root.path}/Library/Containers/com.example.flowlog/Data/Documents/flowlog.sqlite',
      );
      await legacyOld.parent.create(recursive: true);
      await legacyNew.parent.create(recursive: true);
      await legacyOld.writeAsString('old');
      await legacyNew.writeAsString('newer');
      await legacyOld.setLastModified(DateTime(2026, 1, 1));
      await legacyNew.setLastModified(DateTime(2026, 5, 11));

      final file = await resolveFlowLogDatabaseFileForTesting(
        appSupportDirectory: appSupport,
        documentsDirectory: documents,
        homeDirectory: root.path,
      );

      expect(file.readAsStringSync(), 'newer');
      expect(legacyNew.existsSync(), isTrue);
    });

    test(
        'replaces an empty target database with a legacy database that has tasks',
        () async {
      final root = await Directory.systemTemp.createTemp('flowlog_db_path_');
      addTearDown(() => root.delete(recursive: true));
      final appSupport = Directory('${root.path}/support');
      final documents = Directory('${root.path}/documents');
      final target = File('${appSupport.path}/FlowLog/flowlog.sqlite');
      final legacy = File(
        '${root.path}/Library/Containers/com.example.flowlog/Data/Documents/flowlog.sqlite',
      );
      await target.parent.create(recursive: true);
      await legacy.parent.create(recursive: true);
      _createTaskDatabase(target, taskCount: 0);
      _createTaskDatabase(legacy, taskCount: 2);

      final file = await resolveFlowLogDatabaseFileForTesting(
        appSupportDirectory: appSupport,
        documentsDirectory: documents,
        homeDirectory: root.path,
      );

      expect(_taskCount(file), 2);
      expect(File('${target.path}.empty-backup').existsSync(), isTrue);
    });

    test(
        'replaces an empty target with the newest non-empty legacy database',
        () async {
      final root = await Directory.systemTemp.createTemp('flowlog_db_path_');
      addTearDown(() => root.delete(recursive: true));
      final appSupport = Directory('${root.path}/support');
      final documents = Directory('${root.path}/documents');
      final target = File('${appSupport.path}/FlowLog/flowlog.sqlite');
      final emptyNewest = File('${documents.path}/flowlog.sqlite');
      final nonEmptyOlder = File(
        '${root.path}/Library/Containers/com.example.flowlog/Data/Documents/flowlog.sqlite',
      );
      await target.parent.create(recursive: true);
      await emptyNewest.parent.create(recursive: true);
      await nonEmptyOlder.parent.create(recursive: true);
      _createTaskDatabase(target, taskCount: 0);
      _createTaskDatabase(emptyNewest, taskCount: 0);
      _createTaskDatabase(nonEmptyOlder, taskCount: 4);
      await emptyNewest.setLastModified(DateTime(2026, 5, 12));
      await nonEmptyOlder.setLastModified(DateTime(2026, 5, 11));

      final file = await resolveFlowLogDatabaseFileForTesting(
        appSupportDirectory: appSupport,
        documentsDirectory: documents,
        homeDirectory: root.path,
      );

      expect(_taskCount(file), 4);
      expect(File('${target.path}.empty-backup').existsSync(), isTrue);
    });

    test('finds legacy container databases when HOME is not available',
        () async {
      final root = await Directory.systemTemp.createTemp('flowlog_db_path_');
      addTearDown(() => root.delete(recursive: true));
      final appSupport = Directory(
          '${root.path}/Library/Application Support/com.example.flowlog');
      final documents = Directory('${root.path}/Documents');
      final target = File('${appSupport.path}/FlowLog/flowlog.sqlite');
      final legacy = File(
        '${root.path}/Library/Containers/com.example.flowlog/Data/Documents/flowlog.sqlite',
      );
      await target.parent.create(recursive: true);
      await legacy.parent.create(recursive: true);
      _createTaskDatabase(target, taskCount: 0);
      _createTaskDatabase(legacy, taskCount: 3);

      final file = await resolveFlowLogDatabaseFileForTesting(
        appSupportDirectory: appSupport,
        documentsDirectory: documents,
        homeDirectory: null,
      );

      expect(_taskCount(file), 3);
    });
  });
}

void _createTaskDatabase(File file, {required int taskCount}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL)');
    for (var i = 0; i < taskCount; i++) {
      db.execute(
        "INSERT INTO tasks (id, title) VALUES ('t$i', 'Task $i')",
      );
    }
  } finally {
    db.dispose();
  }
}

int _taskCount(File file) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    return db.select('SELECT COUNT(*) AS count FROM tasks').first['count']
        as int;
  } finally {
    db.dispose();
  }
}
