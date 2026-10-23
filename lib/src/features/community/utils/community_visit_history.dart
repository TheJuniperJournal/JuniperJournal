import 'package:shared_preferences/shared_preferences.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/db/models/community.dart';

/// Per-account visits on this device; never shares one user's rankings with another.
class CommunityVisitHistory {
  static String get _prefix =>
      'communityVisits.${AuthService.instance.currentUser?.id ?? 'guest'}.';

  static Future<void> record(String communityId) async {
    final prefix = _prefix;
    final prefs = await SharedPreferences.getInstance();
    final key = '$prefix$communityId';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  static Future<List<Community>> rank(List<Community> communities) async {
    final prefix = _prefix;
    final prefs = await SharedPreferences.getInstance();
    final originalOrder = {
      for (var i = 0; i < communities.length; i++) communities[i].id: i,
    };
    return List<Community>.of(communities)..sort((a, b) {
      final byVisits = (prefs.getInt('$prefix${b.id}') ?? 0).compareTo(
        prefs.getInt('$prefix${a.id}') ?? 0,
      );
      return byVisits != 0
          ? byVisits
          : originalOrder[a.id]!.compareTo(originalOrder[b.id]!);
    });
  }
}
