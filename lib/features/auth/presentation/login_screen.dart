import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../application/auth_controller.dart';
import 'tenant_selection_sheet.dart';

/// WhatsApp-style premium light-themed login screen with modern multi-device layout (iOS/Android/iPad)
/// and WhatsApp post-login sync transition effect matching the Home screen light theme.
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
  bool _showSuccessTransition = false;
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
      if (!mounted) return;
      // Trigger WhatsApp-style post-login sync transition in light mode
      setState(() {
        _submitting = false;
        _showSuccessTransition = true;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) context.go('/home');
    } on MultipleTenantsFailure catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final choice = await showTenantSelectionSheet(context, e.tenants);
      if (choice != null && mounted) {
        await _attemptSignIn(tenantId: choice.tenantId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e
              .toString()
              .replaceFirst('Failure(', '')
              .replaceFirst(')', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fresh Light VCloud Mint Gradient Background (Harmonizes with Home Screen Light Theme)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F5E9), // Soft Mint Top
                  Color(0xFFF1F8E9), // Light Fresh Green Accent
                  Color(0xFFF8FAFC), // Crisp Off-White Bottom
                ],
              ),
            ),
          ),

          // Ambient Brand Glow (Soft Emerald Radial Aura)
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
            ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut).then().scale(begin: const Offset(1, 1), end: const Offset(0.85, 0.85)),
          ),

          // Main Responsive Content (Tablet / Phone / iPad)
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),

                        // Clean Borderless Brand Logo
                        const Center(
                          child: BrandLogo(height: 105),
                        ).animate().fade(duration: 600.ms).slideY(begin: -0.2, end: 0),

                        const SizedBox(height: 32),

                        // Form Card (Crisp White Card matching Home Screen Surface)
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
                                'Chào mừng trở lại 👋',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Đăng nhập vào tài khoản VCloud của bạn.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Email Input
                              TextFormField(
                                controller: _email,
                                focusNode: _emailFocus,
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Email tài khoản',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(LucideIcons.mail, size: 20, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập email' : null,
                              ),
                              const SizedBox(height: 16),

                              // Password Input
                              TextFormField(
                                controller: _password,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(LucideIcons.lock, size: 20, color: Color(0xFF10B981)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                      size: 20,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                  ),
                                ),
                                autofillHints: const [AutofillHints.password],
                                validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                              ),

                              // Error Banner
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.alertCircle, color: Color(0xFFDC2626), size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().shake(duration: 400.ms),
                              ],

                              const SizedBox(height: 24),

                              // WhatsApp Style Primary Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.35),
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
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Đăng nhập',
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
                            ],
                          ),
                        ).animate().fade(duration: 700.ms, delay: 200.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 20),

                        // Create Account Link
                        TextButton(
                          onPressed: () => context.push('/signup'),
                          child: const Text(
                            'Tạo tài khoản mới',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Light Mode WhatsApp Style Post-Login Sync Overlay
          if (_showSuccessTransition)
            const _WhatsAppSuccessOverlay(),
        ],
      ),
    );
  }
}

/// WhatsApp/Telegram-style post-login splash transition screen in Light Mode.
class _WhatsAppSuccessOverlay extends StatefulWidget {
  const _WhatsAppSuccessOverlay();

  @override
  State<_WhatsAppSuccessOverlay> createState() => _WhatsAppSuccessOverlayState();
}

class _WhatsAppSuccessOverlayState extends State<_WhatsAppSuccessOverlay> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _step = 1);
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => _step = 2);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Animated Emerald Checkmark Badge
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.check,
                  color: Color(0xFF10B981),
                  size: 44,
                ),
              ),
            )
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut)
                .fade(duration: 300.ms),

            const SizedBox(height: 28),

            const Text(
              'Đăng nhập thành công!',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 10),

            // Dynamic Step Subtitle
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _step == 0
                    ? 'Đã xác thực tài khoản...'
                    : (_step == 1 ? 'Đang kết nối VCloud Server...' : 'Đồng bộ dữ liệu mã hóa...'),
                key: ValueKey(_step),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Spacer(),

            // WhatsApp Style Bottom Progress Line in Light Theme
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeInOut,
                  width: _step == 0 ? 80 : (_step == 1 ? 200 : MediaQuery.of(context).size.width - 96),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF10B981),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms);
  }
}
