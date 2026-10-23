/// Static helpers for validating and sanitizing user-supplied input before it
/// reaches the network layer. Server-side validation is the real enforcement
/// boundary; these checks provide fast UX feedback and reduce wasted API calls.
class InputValidator {
  InputValidator._();

  static const int kEmailMaxLen = 254;
  static const int kUsernameMinLen = 3;
  static const int kUsernameMaxLen = 30;
  static const int kPasswordMinLen = 8;
  static const int kPasswordMaxLen = 128;
  static const int kDisplayNameMaxLen = 50;
  static const int kProjectNameMaxLen = 100;
  static const int kProblemStatementMaxLen = 5000;
  static const int kCommentMaxLen = 5000;
  static const int kJournalTitleMaxLen = 200;
  static const int kSearchQueryMaxLen = 100;
  static const int kTagMaxLen = 50;
  static const int kTagsMaxCount = 10;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_-]+$');

  /// Returns an error string, or null if the value is valid.
  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Email is required';
    if (v.length > kEmailMaxLen) return 'Email is too long';
    if (!_emailRe.hasMatch(v)) return 'Please enter a valid email address';
    return null;
  }

  /// Enforces minimum length — use only on the signup path.
  static String? password(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < kPasswordMinLen) {
      return 'Password must be at least $kPasswordMinLen characters';
    }
    if (value.length > kPasswordMaxLen) {
      return 'Password must be at most $kPasswordMaxLen characters';
    }
    return null;
  }

  static String? username(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Username is required';
    if (v.length < kUsernameMinLen) {
      return 'Username must be at least $kUsernameMinLen characters';
    }
    if (v.length > kUsernameMaxLen) {
      return 'Username must be at most $kUsernameMaxLen characters';
    }
    if (!_usernameRe.hasMatch(v)) {
      return 'Username may only contain letters, numbers, underscores, and hyphens';
    }
    return null;
  }

  /// Returns null when the value is empty (display name is optional).
  static String? displayName(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    if (v.length > kDisplayNameMaxLen) {
      return 'Display name must be at most $kDisplayNameMaxLen characters';
    }
    return null;
  }

  static String? projectName(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Project name is required';
    if (v.length > kProjectNameMaxLen) {
      return 'Project name must be at most $kProjectNameMaxLen characters';
    }
    return null;
  }

  static String? problemStatement(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Problem statement is required';
    if (v.length > kProblemStatementMaxLen) {
      return 'Problem statement must be at most $kProblemStatementMaxLen characters';
    }
    return null;
  }

  static String? comment(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Comment cannot be empty';
    if (v.length > kCommentMaxLen) {
      return 'Comment must be at most $kCommentMaxLen characters';
    }
    return null;
  }

  static String? journalTitle(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Title is required';
    if (v.length > kJournalTitleMaxLen) {
      return 'Title must be at most $kJournalTitleMaxLen characters';
    }
    return null;
  }

  static String? tags(List<String> value) {
    if (value.length > kTagsMaxCount) {
      return 'Maximum $kTagsMaxCount tags allowed';
    }
    for (final tag in value) {
      // Legacy project tags store subject and topic as "subject|topic".
      // Apply the normal limit to each component, not their combined length.
      final parts = tag.trim().split('|');
      final structured =
          parts.length == 2 &&
          parts.every(
            (part) =>
                part.trim().isNotEmpty && part.trim().length <= kTagMaxLen,
          );
      if (!structured && tag.trim().length > kTagMaxLen) {
        return 'Each tag must be at most $kTagMaxLen characters';
      }
    }
    return null;
  }

  static String? searchQuery(String value) {
    if (value.trim().length > kSearchQueryMaxLen)
      return 'Search query is too long';
    return null;
  }
}
