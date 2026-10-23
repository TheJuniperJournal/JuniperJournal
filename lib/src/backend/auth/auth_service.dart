import 'package:flutter/foundation.dart';
import 'auth_redirect.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/supabase_database.dart';
import '../security/input_validator.dart';
import '../storage/storage_service.dart';
import 'package:flutter/material.dart';

/// Service class that handles all authentication operations using Supabase Auth.
///
/// This class provides methods for:
/// - Email/password authentication (login, signup, logout)
/// - OAuth providers (Google, etc.)
/// - Password reset
/// - User session management
///
/// All methods return a response object or throw exceptions that should be
/// handled by the UI layer.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => SupabaseDatabase.instance.client;

  /// Returns the currently logged-in user, or null if not authenticated
  User? get currentUser => _client.auth.currentUser;

  /// Listen to auth state changes
  ///
  /// Returns a stream that emits whenever the auth state changes
  /// (login, logout, token refresh, etc.)
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Get the current user's session
  ///
  /// Returns null if no active session
  Session? get currentSession => _client.auth.currentSession;

  /// Returns true if a user is currently logged in
  bool get isLoggedIn => currentUser != null;

  void logCurrentUser() {
    assert(() {
      debugPrint('Current user: ${currentUser?.email} (${currentUser?.id})');
      return true;
    }());
  }

  /// Sign up a new user with email and password
  ///
  /// Returns a [SignUpResult] with a friendly error message on failure.
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
    DateTime? birthday,
  }) async {
    // Validate inputs before hitting the network
    final emailErr = InputValidator.email(email);
    if (emailErr != null) {
      return SignUpResult(
        user: null,
        session: null,
        requiresEmailConfirmation: false,
        friendlyErrorMessage: emailErr,
      );
    }
    final passwordErr = InputValidator.password(password);
    if (passwordErr != null) {
      return SignUpResult(
        user: null,
        session: null,
        requiresEmailConfirmation: false,
        friendlyErrorMessage: passwordErr,
      );
    }
    if (username != null && username.trim().isNotEmpty) {
      final usernameErr = InputValidator.username(username);
      if (usernameErr != null) {
        return SignUpResult(
          user: null,
          session: null,
          requiresEmailConfirmation: false,
          friendlyErrorMessage: usernameErr,
        );
      }
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      final nameErr = InputValidator.displayName(displayName);
      if (nameErr != null) {
        return SignUpResult(
          user: null,
          session: null,
          requiresEmailConfirmation: false,
          friendlyErrorMessage: nameErr,
        );
      }
    }

    try {
      final data = <String, dynamic>{};
      if (username != null && username.trim().isNotEmpty) {
        data['username'] = username.trim().toLowerCase();
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        data['display_name'] = displayName.trim();
      }
      if (birthday != null) {
        data['birthday'] = birthday.toIso8601String().split('T').first;
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: data.isEmpty ? null : data,
        emailRedirectTo: kIsWeb
            ? authRedirect(isWeb: true, base: Uri.base)
            : null,
      );
      return SignUpResult(
        user: response.user,
        session: response.session,
        requiresEmailConfirmation: response.session == null,
      );
    } on AuthApiException catch (e) {
      final code = e.code ?? '';
      debugPrint(
        'signUpWithEmail AuthApiException: code=$code status=${e.statusCode} message=${e.message}',
      );
      String message;
      if (code == 'email_address_invalid') {
        message = 'Please enter a valid email address.';
      } else if (code == 'email_exists' || code == 'user_already_exists') {
        message = 'Signup failed. Please try again.';
      } else if (code == 'unexpected_failure') {
        message = 'Signup failed. Check your Supabase profiles trigger/schema.';
      } else {
        message = 'Signup failed. Please try again.';
      }
      return SignUpResult(
        user: null,
        session: null,
        requiresEmailConfirmation: false,
        friendlyErrorMessage: message,
        rawErrorCode: code,
        rawStatusCode: int.tryParse(e.statusCode ?? ''),
      );
    }
  }

  /// Checks if an email address is available for registration.
  ///
  /// Calls the `check-email-available` Edge Function server-side.
  /// Returns true if available, false if taken.
  /// Fails open (returns true) on network errors to avoid blocking signup.
  Future<bool> checkEmailAvailable(String email) async {
    try {
      final response = await _client.functions.invoke(
        'check-email-available',
        body: {'email': email.trim()},
      );
      final data = response.data as Map<String, dynamic>;
      return data['available'] as bool? ?? true;
    } catch (e) {
      debugPrint('checkEmailAvailable error: $e');
      return true;
    }
  }

  /// Resend the confirmation email for a pending signup.
  Future<bool> resendVerificationEmail(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
      return true;
    } catch (e) {
      debugPrint('resendVerificationEmail error: $e');
      return false;
    }
  }

  /// Change the current user's password after re-authenticating.
  ///
  /// Returns null on success, or a user-facing error string on failure.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentUser?.email;
    if (email == null) return 'You must be logged in to change your password.';
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthApiException catch (e) {
      final code = e.code ?? '';
      if (code == 'invalid_credentials') {
        return 'Current password is incorrect.';
      }
      return 'Failed to update password. Please try again.';
    } catch (_) {
      return 'Failed to update password. Please try again.';
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } catch (_) {
      return 'Failed to update password. Please try again.';
    }
  }

  /// Sign in an existing user with email and password
  ///
  /// Throws an exception if login fails
  /// Returns the user object on success
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    return response.user;
  }

  /// Sign in using a username instead of an email.
  ///
  /// Calls the `login-with-username` Edge Function which resolves the email
  /// server-side so it is never exposed to the client. Returns the user on
  /// success, or throws [AuthApiException] / [Exception] on failure.
  Future<User?> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final usernameErr = InputValidator.username(username);
    if (usernameErr != null) throw Exception(usernameErr);
    if (password.isEmpty) throw Exception('Password is required');
    if (password.length > InputValidator.kPasswordMaxLen) {
      throw Exception('Password is too long');
    }

    final response = await _client.functions.invoke(
      'login-with-username',
      body: {'username': username, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw AuthApiException(data['error'].toString());
    }

    // Restore the session locally using the returned refresh token
    final authResponse = await _client.auth.setSession(
      data['refresh_token'].toString(),
    );
    return authResponse.user;
  }

  /// Sign in with Google OAuth
  ///
  /// Opens browser for Google authentication
  /// Throws an exception if OAuth fails
  Future<bool> signInWithGoogle() async {
    final response = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirect(isWeb: kIsWeb, base: Uri.base),
    );

    return response;
  }

  /// Sign out the current user
  ///
  /// Throws an exception if logout fails
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send a password reset email to the user
  ///
  /// Throws an exception if the request fails
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: authRedirect(isWeb: kIsWeb, base: Uri.base),
    );
  }

  /// Update the current user's password
  ///
  /// Requires the user to be logged in
  /// Throws an exception if update fails
  Future<User?> updatePassword(String newPassword) async {
    final response = await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    return response.user;
  }

  /// Update the current user's profile metadata (avatar, visibility, etc.)
  Future<User?> updateProfile({
    String? avatarUrl,
    bool? isPublicProfile,
  }) async {
    final data = <String, dynamic>{};
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (isPublicProfile != null) data['is_public_profile'] = isPublicProfile;
    if (data.isEmpty) return currentUser;

    try {
      final response = await _client.auth.updateUser(
        UserAttributes(data: data),
      );
      return response.user;
    } catch (e) {
      debugPrint('updateProfile error: $e');
      return null;
    }
  }

  /// Refresh the current session
  ///
  /// Useful for keeping the user logged in
  Future<Session?> refreshSession() async {
    final response = await _client.auth.refreshSession();
    return response.session;
  }

  /// Permanently deletes the current user's account via a Postgres RPC function.
  /// Requires the `delete_user` function to exist in the database (see docs).
  Future<bool> deleteAccount() async {
    try {
      await StorageService().deleteAccountUploads();
      await _client.rpc('delete_user');
      await _client.auth.signOut();
      return true;
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      return false;
    }
  }
}

/// Result object returned from signup
class SignUpResult {
  final User? user;
  final Session? session;
  final bool requiresEmailConfirmation;

  /// If non-null, signup failed and this is the user-friendly error
  final String? friendlyErrorMessage;

  /// Optional raw values for debugging/logging
  final String? rawErrorCode;
  final int? rawStatusCode;

  const SignUpResult({
    required this.user,
    required this.session,
    required this.requiresEmailConfirmation,
    this.friendlyErrorMessage,
    this.rawErrorCode,
    this.rawStatusCode,
  });

  bool get isSuccess => friendlyErrorMessage == null;
}
