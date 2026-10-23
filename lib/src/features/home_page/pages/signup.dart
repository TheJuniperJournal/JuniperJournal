import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/page_refresh_state.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PageRefreshState.remember(context, {'kind': 'signup'});
    });
  }

  int _step = 0;
  int _prevStep = 0;

  final _usersRepo = UsersRepo();

  // Step 0 — Email
  final _step0Key = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailChecking = false;
  String? _emailError;

  // Step 1 — Password
  final _step1Key = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 2 — Profile
  final _step2Key = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool? _usernameAvailable; // null = unchecked, true = available, false = taken
  bool _usernameChecking = false;
  Timer? _usernameDebounce;

  // Step 3 — Birthday
  DateTime? _birthday;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _goBack() {
    if (_step > 0) {
      setState(() {
        _prevStep = _step;
        _step--;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  void _advance() {
    setState(() {
      _prevStep = _step;
      _step++;
    });
  }

  // ---------------------------------------------------------------------------
  // Step actions
  // ---------------------------------------------------------------------------

  Future<void> _onStep0Next() async {
    if (!(_step0Key.currentState?.validate() ?? false)) return;

    setState(() {
      _emailChecking = true;
      _emailError = null;
    });

    final available = await AuthService.instance.checkEmailAvailable(
      _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _emailChecking = false);

    if (!available) {
      setState(
        () => _emailError = 'An account with this email already exists.',
      );
      return;
    }

    _advance();
  }

  void _onStep1Next() {
    if (!(_step1Key.currentState?.validate() ?? false)) return;
    _advance();
  }

  void _onStep2Next() {
    if (!(_step2Key.currentState?.validate() ?? false)) return;

    final uname = _usernameCtrl.text.trim();
    if (uname.length >= 3) {
      if (_usernameChecking) {
        _showError('Checking username availability, please wait…');
        return;
      }
      if (_usernameAvailable != true) {
        _showError('Please choose an available username.');
        return;
      }
    }

    _advance();
  }

  Future<void> _onSubmit() async {
    if (_birthday == null) {
      _showError('Please select your birthday.');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await AuthService.instance.signUpWithEmail(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      username: _usernameCtrl.text.trim(),
      displayName: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'
          .trim(),
      birthday: _birthday,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isSubmitting = false);
      _showError(result.friendlyErrorMessage ?? 'Signup failed.');
      return;
    }

    if (result.user == null) {
      setState(() => _isSubmitting = false);
      _showError('Signup failed.');
      return;
    }

    if (!result.requiresEmailConfirmation) {
      final displayName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

      await _usersRepo.upsertCurrentUserProfile(
        username: _usernameCtrl.text.trim(),
        displayName: displayName,
        birthday: _birthday,
      );
    }

    if (!mounted) return;
    if (result.requiresEmailConfirmation) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              EmailVerificationPendingScreen(email: _emailCtrl.text.trim()),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShellScreen()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------------------
  // Username availability check (debounced)
  // ---------------------------------------------------------------------------

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _usernameChecking = false;
      });
      return;
    }

    setState(() {
      _usernameChecking = true;
      _usernameAvailable = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await _usersRepo.isUsernameAvailable(trimmed);
      if (!mounted) return;
      setState(() {
        _usernameAvailable = available;
        _usernameChecking = false;
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Birthday picker
  // ---------------------------------------------------------------------------

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  String _formatBirthday(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  void _showError(String message) {
    showTopSnackBar(context, message, isError: true);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
            onPressed: (_emailChecking || _isSubmitting) ? null : _goBack,
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 900;
              final form = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    _StepDots(current: _step, total: 4),
                    const SizedBox(height: AppMetrics.fieldGap),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, animation) {
                          final isForward = _step > _prevStep;
                          final incomingOffset = Offset(
                            isForward ? 1.0 : -1.0,
                            0.0,
                          );
                          final outgoingOffset = Offset(
                            isForward ? -1.0 : 1.0,
                            0.0,
                          );
                          final isIncoming = child.key == ValueKey(_step);
                          final offset = isIncoming
                              ? incomingOffset
                              : outgoingOffset;
                          return SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: offset,
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                            child: child,
                          );
                        },
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: SingleChildScrollView(
                            child: _buildCurrentStep(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final artwork = Image.asset(
                'assets/auth_flower_face.png',
                key: const ValueKey('signup-floral-artwork'),
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              );
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: desktop
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 24,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: (constraints.maxHeight - 48).clamp(
                                    300.0,
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
                              Expanded(
                                flex: 4,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 468,
                                    ),
                                    child: form,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            if (constraints.maxHeight >= 600) ...[
                              SizedBox(height: 140, child: artwork),
                              const SizedBox(height: 12),
                              const Text(
                                'Learn. Create. Grow.',
                                style: TextStyle(
                                  color: Color(0xFF204C35),
                                  fontSize: 14,
                                  letterSpacing: .8,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Expanded(child: form),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Email
  // ---------------------------------------------------------------------------

  Widget _buildStep0() {
    return Form(
      key: _step0Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeading(title: "What's your email?"),
          const SizedBox(height: AppMetrics.sectionGap),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: authInputDecoration('Enter your email'),
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_emailError != null) {
                setState(() => _emailError = null);
              }
            },
            onFieldSubmitted: (_) => _onStep0Next(),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Enter your email';
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          if (_emailError != null) ...[
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: AppColors.error,
                ),
                children: [
                  TextSpan(text: _emailError),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: 'Log in instead?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => Navigator.pushNamed(context, '/login'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppMetrics.sectionGap),
          SubmitButton(
            label: 'Next',
            isLoading: _emailChecking,
            onPressed: _onStep0Next,
            backgroundColor: AppColors.primary,
          ),
          const SizedBox(height: AppMetrics.fieldGap),
          _LoginLink(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Password
  // ---------------------------------------------------------------------------

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeading(title: 'Create a password'),
          const SizedBox(height: AppMetrics.sectionGap),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: authInputDecoration('Password').copyWith(
              suffixIcon: _VisibilityToggle(
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return 'Enter a password';
              if (value.contains(RegExp(r'\s'))) {
                return 'Password cannot contain spaces';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: _obscureConfirm,
            decoration: authInputDecoration('Confirm password').copyWith(
              suffixIcon: _VisibilityToggle(
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onStep1Next(),
            validator: (v) {
              if ((v ?? '') != _passwordCtrl.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: AppMetrics.sectionGap),
          SubmitButton(
            label: 'Next',
            isLoading: false,
            onPressed: _onStep1Next,
            backgroundColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Profile
  // ---------------------------------------------------------------------------

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeading(title: 'Set up your profile'),
          const SizedBox(height: AppMetrics.sectionGap),
          TextFormField(
            controller: _firstNameCtrl,
            decoration: authInputDecoration('First name'),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter your first name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameCtrl,
            decoration: authInputDecoration('Last name'),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter your last name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameCtrl,
            decoration: authInputDecoration('Username'),
            textInputAction: TextInputAction.done,
            onChanged: _onUsernameChanged,
            onFieldSubmitted: (_) => _onStep2Next(),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Enter a username';
              if (value.length < 3) {
                return 'Username must be at least 3 characters';
              }
              if (value.length > 30) {
                return 'Username must be 30 characters or fewer';
              }
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                return 'Only letters, numbers, and underscores allowed';
              }
              return null;
            },
          ),
          _UsernameStatus(
            checking: _usernameChecking,
            available: _usernameAvailable,
            hasInput: _usernameCtrl.text.trim().length >= 3,
          ),
          const SizedBox(height: AppMetrics.sectionGap),
          SubmitButton(
            label: 'Next',
            isLoading: false,
            onPressed: _onStep2Next,
            backgroundColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Birthday
  // ---------------------------------------------------------------------------

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading(title: 'When were you born?'),
        const SizedBox(height: AppMetrics.sectionGap),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          title: Text(
            _birthday != null
                ? _formatBirthday(_birthday!)
                : 'Select your birthday',
            style: TextStyle(
              color: _birthday != null
                  ? AppColors.textPrimary
                  : AppColors.hintText,
            ),
          ),
          trailing: const Icon(Icons.calendar_today_outlined, size: 20),
          onTap: _pickBirthday,
        ),
        const SizedBox(height: 12),
        const Text(
          'We use your birthday to help keep younger users safe.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        SubmitButton(
          label: 'Create Account',
          isLoading: _isSubmitting,
          onPressed: _onSubmit,
          backgroundColor: AppColors.primary,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i <= current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: current == i ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.borderLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: AppTypography.headingFamily,
        fontSize: AppTypography.displaySize,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.obscure, required this.onToggle});

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      onPressed: onToggle,
    );
  }
}

class _UsernameStatus extends StatelessWidget {
  const _UsernameStatus({
    required this.checking,
    required this.available,
    required this.hasInput,
  });

  final bool checking;
  final bool? available;
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    if (!hasInput) return const SizedBox.shrink();

    if (checking) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, left: 4),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (available == true) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, left: 4),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.primary,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Available',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.primary,
                fontSize: AppTypography.helperSize,
              ),
            ),
          ],
        ),
      );
    }

    if (available == false) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, left: 4),
        child: Text(
          'Already taken',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.error,
            fontSize: AppTypography.helperSize,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _LoginLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Already have an account?  '),
        AppTapTarget(
          onTap: () => Navigator.pushNamed(context, '/login'),
          child: const Text(
            'Login',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
