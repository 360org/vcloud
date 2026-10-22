import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../application/auth_controller.dart';
import 'tenant_selection_sheet.dart';

/// Signup screen — WhatsApp-style premium light-themed UI đồng bộ hoàn toàn với LoginScreen.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _submitting = false;
  String? _error;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _toggleRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;
    _toggleRecognizer = TapGestureRecognizer()..onTap = _toggleTerms;
  }

  void _toggleTerms() {
    setState(() {
      _acceptTerms = !_acceptTerms;
      if (_acceptTerms && _error != null) {
        _error = null;
      }
    });
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://vuahethong.net/dieu-khoan-dich-vu');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse('https://vuahethong.net/chinh-sach-bao-mat');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _toggleRecognizer.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      setState(() {
        _error = 'Vui lòng đọc và đồng ý với Điều khoản dịch vụ và Chính sách bảo mật.';
      });
      return;
    }
    await _attemptSignUp();
  }

  Future<void> _attemptSignUp({int? tenantId}) async {
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).signUp(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            phone: _phone.text.trim(),
            acceptTerms: _acceptTerms,
            confirmPassword: _confirmPassword.text,
            tenantId: tenantId,
          );
      if (mounted) context.go('/home');
    } on MultipleTenantsFailure catch (e) {
      if (!mounted) return;
      final choice = await showTenantSelectionSheet(context, e.tenants);
      if (choice != null && mounted) {
        await _attemptSignUp(tenantId: choice.tenantId);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e
              .toString()
              .replaceFirst('Exception: ', '')
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
      body: Stack(
        children: [
          // 1. Soft Mint to Slate Gradient Background (đồng bộ chuẩn LoginScreen)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F5E9),
                  Color(0xFFF1F8E9),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
          ),

          // 2. Ambient Pulsing Glow Circle
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width / 2 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
              ),
            )
                .animate()
                .scale(duration: 2.seconds, curve: Curves.easeInOut)
                .then()
                .scale(begin: const Offset(1, 1), end: const Offset(0.85, 0.85)),
          ),

          // 3. Main Responsive Form Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),

                        // Brand Logo (nằm nổi bật trực tiếp trên nền gradient, không bọc hộp trắng)
                        const Center(
                          child: BrandLogo(height: 96),
                        )
                            .animate()
                            .fade(duration: 600.ms)
                            .slideY(begin: -0.2, end: 0),

                        const SizedBox(height: 24),

                        // Form Card Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đăng ký tài khoản',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tự đăng ký bằng email công việc của bạn.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Name Input
                              TextFormField(
                                key: const ValueKey('signup_name_input'),
                                controller: _name,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Họ và tên',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(
                                    LucideIcons.user,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Vui lòng nhập họ tên'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Phone Input
                              TextFormField(
                                key: const ValueKey('signup_phone_input'),
                                controller: _phone,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Số điện thoại',
                                  hintText: 'VD: 0912345678',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12.5,
                                  ),
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(
                                    LucideIcons.phone,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                                autofillHints: const [AutofillHints.telephoneNumber],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Vui lòng nhập số điện thoại';
                                  }
                                  final clean = v.trim().replaceAll(RegExp(r'[\s.-]'), '');
                                  if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(clean)) {
                                    return 'Số điện thoại không hợp lệ (VD: 0912345678)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Email Input
                              TextFormField(
                                key: const ValueKey('signup_email_input'),
                                controller: _email,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(
                                    LucideIcons.mail,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Vui lòng nhập email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(v.trim())) {
                                    return 'Email không đúng định dạng';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Input
                              TextFormField(
                                key: const ValueKey('signup_password_input'),
                                controller: _password,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu (tối thiểu 6)',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(
                                    LucideIcons.lock,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                      size: 20,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'Dùng ít nhất 6 ký tự'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password Input
                              TextFormField(
                                key: const ValueKey('signup_confirm_password_input'),
                                controller: _confirmPassword,
                                obscureText: _obscureConfirmPassword,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Xác nhận mật khẩu',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(
                                    LucideIcons.shieldCheck,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
                                      size: 20,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Vui lòng xác nhận mật khẩu';
                                  }
                                  if (v != _password.text) {
                                    return 'Mật khẩu xác nhận không khớp';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Accept Terms Checkbox
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _acceptTerms,
                                      activeColor: const Color(0xFF10B981),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _acceptTerms = val ?? false;
                                          if (_acceptTerms && _error != null) {
                                            _error = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text.rich(
                                        TextSpan(
                                          text: 'Tôi đồng ý với ',
                                          recognizer: _toggleRecognizer,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                            height: 1.45,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'Điều khoản dịch vụ',
                                              recognizer: _termsRecognizer,
                                              style: const TextStyle(
                                                color: Color(0xFF0077CD),
                                                fontWeight: FontWeight.w700,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '\nvà ',
                                              recognizer: _toggleRecognizer,
                                            ),
                                            TextSpan(
                                              text: 'Chính sách bảo mật',
                                              recognizer: _privacyRecognizer,
                                              style: const TextStyle(
                                                color: Color(0xFF0077CD),
                                                fontWeight: FontWeight.w700,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Error Alert Banner
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFF87171),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.alertTriangle,
                                          color: Color(0xFFDC2626),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().shake(duration: 450.ms, hz: 4),
                              ],

                              const SizedBox(height: 24),

                              // Submit Button (ElevatedButton emerald green #10B981)
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  key: const ValueKey('signup_submit_btn'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    shadowColor: const Color(0xFF10B981)
                                        .withValues(alpha: 0.35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _submitting ? null : _submit,
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Đăng ký',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(LucideIcons.arrowRight, size: 20),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Bottom Link to Login
                              Center(
                                child: TextButton(
                                  key: const ValueKey('signup_to_login_btn'),
                                  onPressed: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/login');
                                    }
                                  },
                                  child: RichText(
                                    text: const TextSpan(
                                      text: 'Bạn đã có tài khoản? ',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Đăng nhập',
                                          style: TextStyle(
                                            color: Color(0xFF0077CD),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fade(duration: 700.ms, delay: 200.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Floating Circular Back Button
          Positioned(
            top: 12,
            left: 16,
            child: SafeArea(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  key: const ValueKey('signup_back_btn'),
                  icon: const Icon(
                    LucideIcons.arrowLeft,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  },
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                  tooltip: 'Quay lại',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
