import 'package:flutter/material.dart';
import '../../features/home_page/pages/login.dart';
import '../../features/home_page/pages/signup.dart';

Future<void> showAccountRequiredPrompt(BuildContext context) async {
  final signup = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Join the conversation'),
      content: const Text(
        'Log in or create an account to save projects and participate.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Keep browsing'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Log in'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Create account'),
        ),
      ],
    ),
  );
  if (signup == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => signup ? const SignupScreen() : const LoginScreen(),
    ),
  );
}
