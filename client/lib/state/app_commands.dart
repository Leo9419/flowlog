import 'dart:async';

enum QuickAddTarget { current, inbox, today }

class AppCommandBus {
  final StreamController<QuickAddTarget> _quickAddController =
      StreamController<QuickAddTarget>.broadcast();

  Stream<QuickAddTarget> get quickAddStream => _quickAddController.stream;

  void triggerQuickAdd(QuickAddTarget target) {
    _quickAddController.add(target);
  }

  void dispose() {
    _quickAddController.close();
  }
}
