import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcloud/core/utils/app_lifecycle_manager.dart';

void main() {
  group('AppLifecycleManager & isAppForegroundProvider Tests', () {
    test('1. isAppForegroundProvider defaults to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isAppForegroundProvider), isTrue);
    });

    test('2. isAppForegroundProvider toggles state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // App backgrounded
      container.read(isAppForegroundProvider.notifier).state = false;
      expect(container.read(isAppForegroundProvider), isFalse);

      // App resumed
      container.read(isAppForegroundProvider.notifier).state = true;
      expect(container.read(isAppForegroundProvider), isTrue);
    });
  });
}
