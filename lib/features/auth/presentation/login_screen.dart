import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/auth_controller.dart';
import 'tenant_selection_sheet.dart';

/// Login screen — gradient background, glass form card, premium branding.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _obscurePassword = true;
  final _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emailFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    await _attemptSignIn();
  }

  Future<void> _attemptSignIn({int? tenantId}) async {
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            _email.text.trim(),
            _password.text,
            tenantId: tenantId,
          );
      if (mounted) context.go('/home');
    } on MultipleTenantsFailure catch (e) {
      // The credentials match several Odoo databases — let the user pick one
      // and retry, forcing that tenant through `tenant_id`.
      if (!mounted) return;
      final choice = await showTenantSelectionSheet(context, e.tenants);
      if (choice != null && mounted) {
        await _attemptSignIn(tenantId: choice.tenantId);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e
              .toString()
              .replaceFirst('Failure(', '')
              .replaceFirst(')', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.brand),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  const _BrandLogo(),
                  const SizedBox(height: 40),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chào mừng trở lại',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đăng nhập vào tài khoản VCloud của bạn.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          focusNode: _emailFocus,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Vui lòng nhập email'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Vui lòng nhập mật khẩu'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 300),
                            builder: (_, v, child) {
                              return Transform.translate(
                                offset: Offset(
                                  (1 - v) * 10 * (v < 0.5 ? 1 : -1),
                                  0,
                                ),
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GradientButton(
                          label: 'Đăng nhập',
                          loading: _submitting,
                          onPressed: _submitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: Text(
                      'Tạo tài khoản mới',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 230,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.midnight.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const BrandLogo(height: 66),
        ),
        const SizedBox(height: 14),
        Text(
          'Vua hệ thống',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
