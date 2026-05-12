import 'package:flowlog_client/state/selection_store.dart';
import 'package:flowlog_client/ui/shell/sidebar.dart';
import 'package:flowlog_client/ui/trash/trash_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shell navigation', () {
    test('Sidebar primary views include the AI assistant entry', () {
      expect(Sidebar.primaryViews, contains(SidebarView.ai));
    });

    test('Trash back button leaves room for macOS window controls', () {
      expect(
        trashLeadingWidthForPlatform(TargetPlatform.macOS),
        greaterThanOrEqualTo(88),
      );
      expect(trashLeadingWidthForPlatform(TargetPlatform.iOS), isNull);
    });
  });
}
