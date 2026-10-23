import 'package:flutter/material.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/security/input_validator.dart';
import '../../../shared/styling/app_colors.dart';
import '../home_page.dart';

/// Request a recovery email or set a password after the email callback.
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    this.updatePassword = false,
    this.recoverySessionVerified = false,
    this.sendEmail,
    this.savePassword,
  });

  final bool updatePassword;
  final bool recoverySessionVerified;
  final Future<void> Function(String)? sendEmail;
  final Future<void> Function(String)? savePassword;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.updatePassword) {
        if (widget.savePassword != null) {
          await widget.savePassword!(_password.text);
        } else {
          if (!widget.recoverySessionVerified ||
              AuthService.instance.currentSession == null) {
            throw StateError('Recovery session is unavailable');
          }
          await AuthService.instance.updatePassword(_password.text);
          await AuthService.instance.signOut();
        }
      } else {
        await (widget.sendEmail ?? AuthService.instance.resetPassword)(
          _email.text.trim(),
        );
      }
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = widget.updatePassword
              ? 'Could not update your password. Request a new recovery email if the link has expired.'
              : 'Could not send the recovery email. Please wait a moment and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset Password')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            if (_done) ...[
              Text(
                widget.updatePassword
                    ? 'Your password has been updated. Log in with your new password.'
                    : 'If an account exists for this email, you’ll receive a password recovery link. Check your inbox and spam folder.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const JuniperAuthScreen()),
                  (_) => false,
                ),
                child: const Text('Back to Log In'),
              ),
            ] else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.updatePassword
                          ? 'Choose a new password for your account.'
                          : 'Enter your account email to receive a password recovery link.',
                    ),
                    const SizedBox(height: 20),
                    if (!widget.updatePassword)
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                            InputValidator.email(value?.trim() ?? ''),
                      ),
                    if (widget.updatePassword) ...[
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                        ),
                        validator: (value) =>
                            InputValidator.password(value ?? ''),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                        ),
                        validator: (value) => value == _password.text
                            ? null
                            : 'Passwords do not match.',
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      if (widget.updatePassword)
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PasswordRecoveryScreen(),
                                ),
                              ),
                          child: const Text('Request a New Recovery Email'),
                        ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : widget.updatePassword
                            ? 'Update Password'
                            : 'Send Recovery Email',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
