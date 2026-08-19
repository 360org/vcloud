import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/utils/local_attachment_cache.dart';
import 'features/chat_v2/application/chat_v2_channels_controller.dart';

void _logDetailedError(Object error, StackTrace? stack, {String context = 'FLUTTER'}) {
  final errStr = error.toString();
  if (errStr.contains('ink_sparkle.frag')) return;
  debugPrint('=== LỖI FLUTTER NGHIÊM TRỌNG [$context] ===');
  debugPrint('Nội dung lỗi: $error');
  if (stack != null) {
    debugPrint('StackTrace chi tiết:\n$stack');
  }
  debugPrint('============================================');
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    await LocalAttachmentCache.ensureInitialized();
    await ChatV2ChannelLocalCache.init();

    // Override default Grey Screen in Release builds with a clear error UI & Copy Log feature
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final errorText = '${details.exception}\n\n${details.stack}';
      return Material(
        color: Colors.white,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bug_report_rounded,
                      color: Color(0xFFEF4444),
                      size: 52,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đã xảy ra sự cố hiển thị',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Text(
                          details.exceptionAsString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: errorText));
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép log lỗi vào bộ nhớ tạm!'),
                                ),
                              );
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Sao chép chi tiết lỗi'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    };

    // Catch unhandled Flutter errors & send to Firebase Crashlytics
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      FlutterError.presentError(details);
      _logDetailedError(details.exception, details.stack, context: 'UI/FRAMEWORK');
    };

    // Catch platform dispatcher errors & send to Firebase Crashlytics
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      _logDetailedError(error, stack, context: 'PLATFORM DISPATCHER');
      return true;
    };

    runApp(const ProviderScope(child: VCloudApp()));
  }, (Object error, StackTrace stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    _logDetailedError(error, stack, context: 'ZONED GUARDED');
  });
}


