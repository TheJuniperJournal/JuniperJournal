import '../supabase_database.dart';

enum FlowerTarget {
  projectComment('project_comment_flowers'),
  journalComment('journal_comment_flowers'),
  communityComment('community_comment_flowers'),
  collaborationComment('collaboration_comment_flowers'),
  message('message_flowers');

  const FlowerTarget(this.table);
  final String table;
}

class FlowerState {
  const FlowerState(this.count, this.selected);
  final int count;
  final bool selected;
}

class FlowerReactionsRepo {
  Future<FlowerState> load(FlowerTarget target, String id) async {
    final client = SupabaseDatabase.instance.client;
    final rows = await client
        .from(target.table)
        .select('user_id')
        .eq('target_id', id);
    final userId = client.auth.currentUser?.id;
    return FlowerState(
      rows.length,
      rows.any((row) => row['user_id'] == userId),
    );
  }

  Future<void> setSelected(
    FlowerTarget target,
    String id,
    bool selected,
  ) async {
    final client = SupabaseDatabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to give a flower.');
    if (selected) {
      await client
          .from(target.table)
          .upsert(
            {'target_id': id, 'user_id': userId},
            onConflict: 'target_id,user_id',
            ignoreDuplicates: true,
          );
    } else {
      await client
          .from(target.table)
          .delete()
          .eq('target_id', id)
          .eq('user_id', userId);
    }
  }
}
