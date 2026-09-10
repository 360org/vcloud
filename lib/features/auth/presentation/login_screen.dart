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
  final _serverUrl = TextEditingController();
  final _databaseName = TextEditingController();
  bool _isManualMode = false;
  bool _submitting = false;
  bool _showSuccessTransition = false;
  String? _error;
  bool _obscurePassword = true;
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _serverUrlFocus = FocusNode();
  final _databaseNameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _email.addListener(_onFieldChanged);
    _password.addListener(_onFieldChanged);
    _serverUrl.addListener(_onFieldChanged);
    _databaseName.addListener(_onFieldChanged);
    _loadSavedEmail();
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
    _email.removeListener(_onFieldChanged);
    _password.removeListener(_onFieldChanged);
    _serverUrl.removeListener(_onFieldChanged);
    _databaseName.removeListener(_onFieldChanged);
    _email.dispose();
    _password.dispose();
    _serverUrl.dispose();
    _databaseName.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _serverUrlFocus.dispose();
    _databaseNameFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // [Giải pháp 2]: Xác thực Mật khẩu TRƯỚC rồi mới chọn Database
  // 1. Gửi login + password lên Master Router
  // 2. Master verify password qua các candidate DBs
  // 3. Nếu 1 DB đúng -> Đăng nhập thẳng
  // 4. Nếu > 1 DB đúng -> Hiện Dialog/Sheet chọn tổ chức
  // 5. Nếu 0 DB đúng -> Báo lỗi "Tài khoản hoặc mật khẩu không chính xác" (chống dò quét DB)
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

    setState(() => _submitting = true);

    try {
      // Chế độ nhập thủ công (Manual Mode Fallback)
      if (_isManualMode) {
        final serverUrl = _serverUrl.text.trim().replaceAll(RegExp(r'/+$'), '');
        final databaseName = _databaseName.text.trim();
        final manualDb = DbInfo(
          login: login,
          databaseName: databaseName,
          databaseUrl: serverUrl,
          hasVMobile: true,
        );
        await _executeClientAuth(
          db: manualDb,
          login: login,
          password: password,
        );
        return;
      }

      final preferredDb = await ref
          .read(authControllerProvider.notifier)
          .getLastSelectedDb();

      debugPrint('🔍 [VCLOUD AUTH] Đang tra cứu cơ sở dữ liệu trên Master: $login (Preferred: $preferredDb)');
      // [Bước 2]: Gửi API tra cứu DB lên Master: POST /api/v1/auth/lookup-db
      // PAYLOAD CHỈ CHỨA: {"login": "<login>"}
      // ⚠️ TUYỆT ĐỐI KHÔNG BẮT GỬI PASSWORD LÊN MASTER!
      final dbs = await ref
          .read(authControllerProvider.notifier)
          .lookupDb(login, preferredDb: preferredDb);

      debugPrint('📋 [VCLOUD AUTH RESULT] Tìm thấy ${dbs.length} database cho tài khoản $login:');
      for (int i = 0; i < dbs.length; i++) {
        debugPrint('   [$i] DB: ${dbs[i].databaseName} | URL: ${dbs[i].databaseUrl}');
      }

      if (!mounted) return;

      // [Bước 3 - Nhánh 3: KHÔNG TỒN TẠI (Master trả về rỗng [])]
      // App thông báo ngay: "Tài khoản không tồn tại trên hệ thống".
      if (dbs.isEmpty) {
        setState(() {
          _submitting = false;
          _error = 'Tài khoản không tồn tại trên hệ thống.';
        });
        AppToast.error(
          context,
          title: 'Đăng nhập thất bại',
          message: 'Tài khoản không tồn tại trên hệ thống.',
        );
        return;
      }

      // [Bước 3 - Nhánh 1: CHỈ CÓ 1 DATABASE]
      // App tự động lấy DB đó và gửi thẳng request authenticate với user/pass vừa nhập.
      // Người dùng vào thẳng app, KHÔNG CẦN CHỌN DB.
      if (dbs.length == 1) {
        final targetDb = dbs.first;
        await _executeClientAuth(
          db: targetDb,
          login: login,
          password: password,
        );
        return;
      }

      // [Bước 3 - Nhánh 2: TRÙNG TẠI NHIỀU DATABASE]
      // BẬT THÊM TRƯỜNG "DATABASE" (Dropdown hoặc Popup để User chọn DB muốn đăng nhập).
      // User bấm chọn -> Bấm Login để vào đúng DB (xác thực trực tiếp tại Client DB).
      setState(() => _submitting = false);
      final selected = await _showOrganizationPickerDialog(dbs);
      if (selected != null && mounted) {
        await _executeClientAuth(
          db: selected,
          login: login,
          password: password,
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('🚨 [LoginScreen.submit] Error: $e\n$st');
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
    }
  }

  Future<DbInfo?> _showOrganizationPickerDialog(List<DbInfo> dbs) {
    return showDialog<DbInfo>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.65),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header sang trọng với Gradient Brand nhẹ
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF10B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.building2,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chọn tổ chức / cơ sở dữ liệu',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Tài khoản hợp lệ tại các đơn vị bên dưới:',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            icon: const Icon(
                              LucideIcons.x,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                            splashRadius: 20,
                            tooltip: 'Đóng',
                          ),
                        ],
                      ),
                    ),

                    // Danh sách Database Items dạng Card hiện đại
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.52,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: dbs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = dbs[index];
                            final is19 = item.categoryLabel.contains('19');
                            final isClient = item.categoryLabel.contains('Khách Hàng');
                            final primaryColor = is19
                                ? const Color(0xFF7C3AED)
                                : (isClient
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF059669));

                            final lightBgColor = primaryColor.withValues(alpha: 0.08);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(ctx).pop(item),
                                borderRadius: BorderRadius.circular(16),
                                hoverColor: primaryColor.withValues(alpha: 0.05),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAFAFA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: lightBgColor,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          is19 ? LucideIcons.server : LucideIcons.database,
                                          color: primaryColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    item.effectiveDisplayName,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                      letterSpacing: -0.2,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: primaryColor.withValues(alpha: 0.2),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.categoryLabel,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                ),
                                                if (!item.hasVMobile) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Chưa cài vmobile',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.databaseUrl,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          LucideIcons.arrowRight,
                                          size: 15,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Bước 4 & 5: Gửi password trực tiếp đến Client DB URL và cấp quyền
  // ---------------------------------------------------------------------------

  Future<void> _executeClientAuth({
    required DbInfo db,
    required String login,
    required String password,
  }) async {
    // Đảm bảo đúng cơ sở dữ liệu theo môi trường mục tiêu (phân tích Host chuẩn)
    var effectiveDb = db;
    final host = Uri.tryParse(db.databaseUrl)?.host.toLowerCase() ?? '';
    if (host == 'vuahethong.net' || host == 'www.vuahethong.net') {
      if (db.databaseName.isEmpty || db.databaseName == 'demo') {
        effectiveDb = DbInfo(
          login: db.login,
          databaseName: 'vuahethong',
          databaseUrl: db.databaseUrl,
          displayName: db.displayName,
          hasVMobile: db.hasVMobile,
          projectId: db.projectId,
        );
      }
    } else if (host == 'demo.vuahethong.com') {
      if (db.databaseName.isEmpty) {
        effectiveDb = DbInfo(
          login: db.login,
          databaseName: 'demo',
          databaseUrl: db.databaseUrl,
          displayName: db.displayName,
          hasVMobile: db.hasVMobile,
          projectId: db.projectId,
        );
      }
    }
    // Đối với các domain khác (ví dụ: tenant khách hàng davita.vn, subdomains), giữ nguyên db do Master trả về!

    setState(() => _submitting = true);
    debugPrint('''
------------------------------------------------------------------
👉 [VCLOUD AUTH INITIATED] BẮT ĐẦU XÁC THỰC
👤 Login   : $login
🗄️ Mục tiêu: ${effectiveDb.databaseName}
🌐 URL đích: ${effectiveDb.databaseUrl}
------------------------------------------------------------------''');
    try {
      await ref.read(authControllerProvider.notifier).authenticateOnClient(
            db: effectiveDb,
            login: login,
            password: password,
          );

      if (!mounted) return;

      // Pre-warm data (chỉ thực hiện nếu database đã cài đặt vmobile)
      if (effectiveDb.hasVMobile) {
        try {
          await Future.wait([
            ref.read(chatV2ChannelsProvider.notifier).refresh(),
          ]).timeout(const Duration(milliseconds: 2500));
        } catch (warmupErr) {
          debugPrint('⚠️ [LoginScreen] Pre-warm data sync timed out: $warmupErr');
        }
      }

      if (!mounted) return;

      // Bước 5: Chuyển hướng màn hình chính
      setState(() {
        _submitting = false;
        _showSuccessTransition = true;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        context.go('/chat');

        // Nếu database chưa được cài đặt module vmobile, hiển thị cảnh báo rõ ràng
        if (!effectiveDb.hasVMobile) {
          Future.delayed(const Duration(milliseconds: 750), () {
            AppToast.showGlobal(
              type: AppToastType.warning,
              title: 'Chưa cài đặt module vmobile',
              message:
                  'Cơ sở dữ liệu "${effectiveDb.databaseName}" chưa cài module vmobile. Tất cả các tính năng không thể sử dụng được.',
              duration: const Duration(seconds: 6),
            );
          });
        }
      }
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
    if (rawMsg.contains('does not exist') || rawMsg.contains('FATAL: database')) {
      return 'Cơ sở dữ liệu không tồn tại hoặc đã bị xóa trên máy chủ.';
    }
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
                                key: const ValueKey('login_email_input'),
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
                                key: const ValueKey('login_password_input'),
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                onFieldSubmitted: (_) {
                                  if (!_submitting) _submit();
                                },
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

                              // Manual Mode Expandable Fields
                              if (_isManualMode) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _serverUrl,
                                  focusNode: _serverUrlFocus,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Địa chỉ máy chủ (URL)',
                                    hintText: 'https://vuahethong.net hoặc http://localhost:8069',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12.5,
                                    ),
                                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                    prefixIcon: const Icon(
                                      LucideIcons.globe,
                                      size: 20,
                                      color: Color(0xFF3B82F6),
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
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3B82F6),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.url,
                                  validator: (v) {
                                    if (!_isManualMode) return null;
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Vui lòng nhập địa chỉ máy chủ';
                                    }
                                    final trimmed = v.trim();
                                    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
                                      return 'URL phải bắt đầu bằng http:// hoặc https://';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _databaseName,
                                  focusNode: _databaseNameFocus,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Tên Database (Cơ sở dữ liệu)',
                                    hintText: 'demo-17, vuahethong...',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12.5,
                                    ),
                                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                                    prefixIcon: const Icon(
                                      LucideIcons.database,
                                      size: 20,
                                      color: Color(0xFF3B82F6),
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
                                      borderSide: const BorderSide(
                                        color: Color(0xFF3B82F6),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (!_isManualMode) return null;
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Vui lòng nhập tên Database';
                                    }
                                    return null;
                                  },
                                ),
                              ],

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
                                  key: const ValueKey('login_submit_btn'),
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
                                              'Đăng nhập',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(LucideIcons.arrowRight,
                                                size: 20),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Toggle Manual Mode Button (Fallback)
                              Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isManualMode = !_isManualMode;
                                      _error = null;
                                    });
                                  },
                                  icon: Icon(
                                    _isManualMode
                                        ? LucideIcons.sparkles
                                        : LucideIcons.slidersHorizontal,
                                    size: 15,
                                    color: const Color(0xFF64748B),
                                  ),
                                  label: Text(
                                    _isManualMode
                                        ? 'Chuyển sang Đăng nhập thông minh (Smart Login)'
                                        : 'Nhập máy chủ / Database thủ công',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
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
