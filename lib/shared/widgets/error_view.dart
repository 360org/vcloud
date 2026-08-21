import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/error/failure.dart';
import 'copyable_error_dialog.dart';
import 'ui_kit.dart';


/// Inline error view with an optional Retry callback. Used by every
/// screen that renders a stream from a repository.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Error: ${describeError(error)}',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            glowColor: AppColors.danger,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.featureGrad(
                      AppColors.danger,
                      AppColors.dangerDeep,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Đã xảy ra lỗi',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  describeError(error),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: OutlinedButton.icon(
                          onPressed: () => showCopyableErrorDialog(
                            context,
                            title: 'Chi Tiết Lỗi System',
                            error: error,
                          ),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Lỗi'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Semantics(
                          button: true,
                          label: 'Thử lại',
                          child: FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Thử lại'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

