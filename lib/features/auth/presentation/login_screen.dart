import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../chat_v2/application/chat_v2_channels_controller.dart';
import '../application/auth_controller.dart';
import '../data/db_info.dart';

/// WhatsApp-style premium light-themed login screen với Master Directory Lookup & Direct Client Auth.
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
  final _passwordFocus = FocusNode();

  // [P1] Quản lý state danh sách Database khi lookup trả về > 1 DB
  List<DbInfo> _availableDbs = [];
  DbInfo? _selectedDb;
  String? _lastLookedUpEmail;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onEmailChanged);
    _password.addListener(_onFieldChanged);
    _loadSavedEmail();
  }

  void _onEmailChanged() {
    // Nếu user đổi email, reset danh sách DB đã lookup
    if (_lastLookedUpEmail != null &&
        _email.text.trim() != _lastLookedUpEmail) {
      if (_availableDbs.isNotEmpty) {
        setState(() {
          _availableDbs = [];
          _selectedDb = null;
          _lastLookedUpEmail = null;
        });
      }
    }
    _onFieldChanged();
  }

  void _onFieldChanged() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  Future<void> _loadSavedEmail() async {
    try {
      final savedEmail =
          await ref.read(authRepositoryProvider).getLastLoginEmail();
      if (!mounted) return;
      if (savedEmail != null && savedEmail.trim().isNotEmpty) {
        final emailText = savedEmail.trim();
        setState(() {
          _email.value = TextEditingValue(
            text: emailText,
            selection: TextSelection.collapsed(offset: emailText.length),
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _passwordFocus.requestFocus();
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _emailFocus.requestFocus();
        });
      }
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emailFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _email.removeListener(_onEmailChanged);
    _password.removeListener(_onFieldChanged);
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // [P1] Luồng đăng nhập 5 bước: Lookup -> Branch DB count -> Direct Auth
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ tài khoản và mật khẩu.';
      });
      AppToast.warning(
        context,
        title: 'Thông tin chưa đầy đủ',
        message: 'Vui lòng nhập đầy đủ tài khoản và mật khẩu để tiếp tục.',
      );
      return;
    }

    final login = _email.text.trim();
    final password = _password.text;

    // Nếu đã có > 1 DB và người dùng đã chọn DB từ Dropdown -> Thực hiện Bước 4
    if (_availableDbs.length > 1 && _selectedDb != null) {
      await _executeClientAuth(db: _selectedDb!, login: login, password: password);
      return;
    }

    setState(() => _submitting = true);

    try {
      // -----------------------------------------------------------------------
      // Bước 2: Tra cứu Routing (Lookup DB) - CHỈ GỬI login LÊN MASTER
      // -----------------------------------------------------------------------
      final dbs = await ref
          .read(authControllerProvider.notifier)
          .lookupDb(login);

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // Bước 3a: 0 DB -> Báo lỗi "Tài khoản không tồn tại"
      // -----------------------------------------------------------------------
      if (dbs.isEmpty) {
        setState(() {
          _submitting = false;
          _error = 'Tài khoản không tồn tại trên hệ thống.';
          _availableDbs = [];
          _selectedDb = null;
        });
        AppToast.error(
          context,
          title: 'Đăng nhập thất bại',
          message: 'Tài khoản không tồn tại trên hệ thống.',
        );
        return;
      }

      // -----------------------------------------------------------------------
      // Bước 3b: Đúng 1 DB -> Tự động xác thực thẳng tới Client DB URL
      // -----------------------------------------------------------------------
      if (dbs.length == 1) {
        final targetDb = dbs.first;
        setState(() {
          _availableDbs = dbs;
          _selectedDb = targetDb;
          _lastLookedUpEmail = login;
        });
        await _executeClientAuth(
          db: targetDb,
          login: login,
          password: password,
        );
        return;
      }

      // -----------------------------------------------------------------------
      // Bước 3c: > 1 DB (Trùng username) -> Render Dropdown để user chọn DB
      // -----------------------------------------------------------------------
      setState(() {
        _submitting = false;
        _availableDbs = dbs;
        _selectedDb = dbs.first; // Mặc định chọn DB đầu tiên trong list
        _lastLookedUpEmail = login;
      });

      AppToast.info(
        context,
        title: 'Chọn cơ sở dữ liệu',
        message:
            'Tài khoản thuộc nhiều hệ thống. Vui lòng chọn cơ sở dữ liệu và nhấn Đăng nhập.',
      );
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('🚨 [LoginScreen.lookupDb] Error: $e\n$st');
      final cleanMsg = _cleanErrorMessage(e);
      setState(() {
        _submitting = false;
        _error = cleanMsg;
      });
      AppToast.error(
        context,
        title: 'Lỗi tra cứu tài khoản',
        message: cleanMsg,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Bước 4 & 5: Gửi password trực tiếp đến Client DB URL và cấp quyền
  // ---------------------------------------------------------------------------

  Future<void> _executeClientAuth({
    required DbInfo db,
    required String login,
    required String password,
  }) async {
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).authenticateOnClient(
            db: db,
            login: login,
            password: password,
          );

      if (!mounted) return;

      // Pre-warm data
      try {
        await Future.wait([
          ref.read(chatV2ChannelsProvider.notifier).refresh(),
        ]).timeout(const Duration(milliseconds: 2500));
      } catch (warmupErr) {
        debugPrint('⚠️ [LoginScreen] Pre-warm data sync timed out: $warmupErr');
      }

      if (!mounted) return;

      // Bước 5: Chuyển hướng màn hình chính
      setState(() {
        _submitting = false;
        _showSuccessTransition = true;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) context.go('/chat');
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('🚨 [LoginScreen._executeClientAuth] Error: $e\n$st');
      final cleanMsg = _cleanErrorMessage(e);
      setState(() {
        _submitting = false;
        _error = cleanMsg;
      });
      AppToast.error(
        context,
        title: 'Đăng nhập thất bại',
        message: cleanMsg,
      );
      _password.clear();
    }
  }

  String _cleanErrorMessage(Object error) {
    final rawMsg = error
        .toString()
        .replaceFirst('Failure: ', '')
        .replaceFirst('Failure(', '')
        .replaceFirst(')', '')
        .trim();
    if (rawMsg.isEmpty ||
        rawMsg == 'invalid_credentials' ||
        rawMsg.contains('invalid_credentials') ||
        rawMsg.contains('Access Denied')) {
      return 'Mật khẩu không chính xác. Vui lòng kiểm tra lại!';
    }
    return rawMsg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
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

          // Ambient Glow
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

          // Main Responsive Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),

                        // Brand Logo
                        const Center(
                          child: BrandLogo(height: 105),
                        )
                            .animate()
                            .fade(duration: 600.ms)
                            .slideY(begin: -0.2, end: 0),

                        const SizedBox(height: 32),

                        // Form Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.08),
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

                              // Email/Login Input
                              TextFormField(
                                controller: _email,
                                focusNode: _emailFocus,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Tài khoản / Email',
                                  labelStyle:
                                      const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: const Icon(
                                    LucideIcons.mail,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _error != null
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFE2E8F0),
                                      width: _error != null ? 1.3 : 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _error != null
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Vui lòng nhập tài khoản hoặc email'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Password Input
                              TextFormField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  labelStyle:
                                      const TextStyle(color: Color(0xFF64748B)),
                                  prefixIcon: Icon(
                                    LucideIcons.lock,
                                    size: 20,
                                    color: _error != null
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF10B981),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? LucideIcons.eyeOff
                                          : LucideIcons.eye,
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
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _error != null
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFE2E8F0),
                                      width: _error != null ? 1.3 : 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: _error != null
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF10B981),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                autofillHints: const [AutofillHints.password],
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Vui lòng nhập mật khẩu'
                                    : null,
                              ),

                              // -------------------------------------------------
                              // [P1 / Bước 3c]: Dropdown chọn Database khi > 1 DB
                              // -------------------------------------------------
                              if (_availableDbs.length > 1) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF86EFAC),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<DbInfo>(
                                      value: _selectedDb,
                                      isExpanded: true,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        size: 20,
                                        color: Color(0xFF10B981),
                                      ),
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      items: _availableDbs.map((db) {
                                        return DropdownMenuItem<DbInfo>(
                                          value: db,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                LucideIcons.database,
                                                size: 18,
                                                color: Color(0xFF10B981),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      db.databaseName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (db.databaseUrl.isNotEmpty)
                                                      Text(
                                                        db.databaseUrl,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (DbInfo? newDb) {
                                        if (newDb != null) {
                                          setState(() => _selectedDb = newDb);
                                        }
                                      },
                                    ),
                                  ),
                                ).animate().fade(duration: 300.ms).slideY(begin: -0.1, end: 0),
                              ],

                              // Error Banner
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                              // Primary Submit Button
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
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
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _availableDbs.length > 1
                                                  ? 'Đăng nhập vào DB đã chọn'
                                                  : 'Đăng nhập',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(LucideIcons.arrowRight,
                                                size: 20),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fade(duration: 700.ms, delay: 200.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Post-Login Success Transition Overlay
          if (_showSuccessTransition) const _WhatsAppSuccessOverlay(),
        ],
      ),
    );
  }
}

/// Post-login splash transition screen.
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _step == 0
                    ? 'Đã xác thực tài khoản...'
                    : (_step == 1
                        ? 'Đang kết nối VCloud Server...'
                        : 'Đồng bộ dữ liệu mã hóa...'),
                key: ValueKey(_step),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
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
                  width: _step == 0
                      ? 80
                      : (_step == 1
                          ? 200
                          : MediaQuery.of(context).size.width - 96),
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
