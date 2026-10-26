import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'password_recovery.dart';
import '../../../shared/widgets/page_refresh_state.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final AuthService _authService = AuthService.instance;
  final _usersRepo = UsersRepo();

  Route<dynamic>? _standaloneRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _standaloneRoute) return;
    _standaloneRoute = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null) {
        PageRefreshState.remember(context, {'kind': 'login'});
        DesktopShellScope.of(context)?.clear();
        desktopRouteObserver.registerStandalone(route, true);
      }
    });
  }

  // Create nodes for easy flow
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    final route = _standaloneRoute;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null) desktopRouteObserver.registerStandalone(route, false);
    });
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Handles email/password login
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() => _isLoading = true);

    try {
      final User? user;
      if (input.contains('@')) {
        user = await _authService.signInWithEmail(
          email: input,
          password: password,
        );
      } else {
        user = await _authService.signInWithUsername(
          username: input,
          password: password,
        );
      }

      if (user != null && mounted) {
        // Backfill the profile row from auth metadata when signup completed
        // before an authenticated session existed.
        await _usersRepo.ensureProfileExists();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const HomeShellScreen(restoreJournal: false),
          ),
          (route) => false,
        );
      }
    } on AuthApiException catch (e) {
      if (mounted) {
        debugPrint('AuthApiException code=${e.code} status=${e.statusCode}');
        _showError(_mapAuthApiError(e));
      }
    } catch (e) {
      debugPrint('Unknown error: $e');
      _showError('Invalid username or password');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows error message as SnackBar
  void _showError(String message) {
    showTopSnackBar(context, message, isError: true);
  }

  String _mapAuthApiError(AuthApiException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Invalid email or password.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  InputDecoration _decoration(String hint) =>
      authInputDecoration(hint).copyWith(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF929B98)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      );

  Widget _loginForm(bool desktop) => AutofillGroup(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(
              fontFamily: AppTypography.headingFamily,
              fontSize: desktop ? 38 : 30,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF204C35),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Document your sustainability journey.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF4A5650),
            ),
          ),
          const SizedBox(height: 36),
          const Text('Email or username', style: AppTypography.fieldLabel),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('login-identity'),
            controller: _emailCtrl,
            focusNode: _usernameFocus,
            enabled: !_isLoading,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            decoration: _decoration('Enter your email or username'),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Enter your email or username'
                : null,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: AppMetrics.fieldGap),
          const Text('Password', style: AppTypography.fieldLabel),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('login-password'),
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            enabled: !_isLoading,
            autofillHints: const [AutofillHints.password],
            obscureText: _obscurePassword,
            enableSuggestions: false,
            autocorrect: false,
            decoration: _decoration('Enter your password').copyWith(
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter your password' : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _handleLogin();
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PasswordRecoveryScreen(),
                      ),
                    ),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: SubmitButton(
              label: 'Log in',
              isLoading: _isLoading,
              onPressed: _handleLogin,
              backgroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              const Text('New to Juniper Journal?'),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.pushNamed(context, '/signup'),
                child: const Text('Sign up'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final form = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _loginForm(desktop),
          );
          final artwork = Image.asset(
            'assets/auth_flower_face.png',
            key: const ValueKey('login-floral-artwork'),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: PageScrollWithFooter(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: desktop ? 48 : 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                key: const ValueKey('login-explore-link'),
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.of(context)
                                          .pushNamedAndRemoveUntil(
                                            '/explore',
                                            (_) => false,
                                          ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text(
                                  'Juniper Journal',
                                  style: TextStyle(
                                    fontFamily: AppTypography.headingFamily,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF204C35),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('login-back-to-explore'),
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                      '/explore',
                                      (_) => false,
                                    ),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Explore'),
                        ),
                      ),
                      SizedBox(height: desktop ? 24 : 12),
                      if (desktop)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 160).clamp(
                              520.0,
                              800.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: (constraints.maxHeight - 170).clamp(
                                    480.0,
                                    680.0,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(child: artwork),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Learn. Create. Grow.',
                                        style: TextStyle(
                                          color: Color(0xFF204C35),
                                          fontSize: 14,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 64),
                              Expanded(flex: 4, child: Center(child: form)),
                            ],
                          ),
                        )
                      else ...[
                        SizedBox(height: 180, child: artwork),
                        const SizedBox(height: 12),
                        const Text(
                          'Learn. Create. Grow.',
                          style: TextStyle(
                            color: Color(0xFF204C35),
                            fontSize: 14,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(child: form),
                      ],
                      SizedBox(height: desktop ? 24 : 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
