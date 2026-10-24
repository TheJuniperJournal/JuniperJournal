import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../../../backend/db/supabase_database.dart';

class MessageLikeReaction extends StatefulWidget {
  const MessageLikeReaction({
    super.key,
    required this.targetId,
    required this.builder,
  });
  final String targetId;
  final Widget Function(BuildContext, VoidCallback, Widget) builder;
  @override
  State<MessageLikeReaction> createState() => _MessageLikeReactionState();
}

class _MessageLikeReactionState extends State<MessageLikeReaction> {
  final _counts = <String, int>{};
  final _selected = <String>{};
  bool _busy = false;
  RealtimeChannel? _channel;
  @override
  void initState() {
    super.initState();
    _load();
    try {
      _channel = SupabaseDatabase.instance.client
          .channel('message-emojis-${widget.targetId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'message_emoji_reactions',
            callback: (_) => _load(),
          )
          .subscribe();
    } catch (_) {
      /* Initial loading still works if realtime is unavailable. */
    }
  }

  @override
  void dispose() {
    if (_channel != null)
      SupabaseDatabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = SupabaseDatabase.instance.client;
      final rows = await client
          .from('message_emoji_reactions')
          .select('emoji,user_id')
          .eq('target_id', widget.targetId)
          .eq('emoji', '🌼');
      if (!mounted) return;
      setState(() {
        _counts.clear();
        _selected.clear();
        for (final row in rows) {
          final emoji = row['emoji'] as String;
          _counts[emoji] = (_counts[emoji] ?? 0) + 1;
          if (row['user_id'] == client.auth.currentUser?.id)
            _selected.add(emoji);
        }
      });
    } catch (_) {
      /* Reactions must not prevent reading a conversation. */
    }
  }

  Future<void> _toggle(String emoji) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final client = SupabaseDatabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw StateError('Sign in to react.');
      await client.rpc(
        'toggle_message_reaction',
        params: {'p_target': widget.targetId, 'p_emoji': emoji},
      );
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save reaction. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    () => _toggle('🌼'),
    (_counts['🌼'] ?? 0) == 0
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
            child: Semantics(
              label: '${_counts['🌼']} likes',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selected.contains('🌼')
                        ? Icons.local_florist
                        : Icons.local_florist_outlined,
                    size: 16,
                    color: const Color(0xFF5DB075),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_counts['🌼']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}
