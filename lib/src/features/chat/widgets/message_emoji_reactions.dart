import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../../../backend/db/supabase_database.dart';

const messageReactionEmojis = ['❤️', '👍', '😂', '🎉', '😮', '😢', '🙏', '🌱'];

class MessageEmojiReactions extends StatefulWidget {
  const MessageEmojiReactions({
    super.key,
    required this.targetId,
    required this.builder,
  });
  final String targetId;
  final Widget Function(BuildContext, VoidCallback, Widget) builder;
  @override
  State<MessageEmojiReactions> createState() => _MessageEmojiReactionsState();
}

class _MessageEmojiReactionsState extends State<MessageEmojiReactions> {
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
          .eq('target_id', widget.targetId);
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
      if (_selected.contains(emoji)) {
        await client
            .from('message_emoji_reactions')
            .delete()
            .eq('target_id', widget.targetId)
            .eq('user_id', user.id)
            .eq('emoji', emoji);
      } else {
        await client
            .from('message_emoji_reactions')
            .upsert(
              {
                'target_id': widget.targetId,
                'user_id': user.id,
                'emoji': emoji,
              },
              onConflict: 'target_id,user_id,emoji',
              ignoreDuplicates: true,
            );
      }
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

  Future<void> _open() async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final point = box.localToGlobal(Offset.zero, ancestor: overlay);
    final emoji = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        point & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final emoji in messageReactionEmojis)
          PopupMenuItem(
            value: emoji,
            child: Text(
              '$emoji${_selected.contains(emoji) ? '  ✓' : ''}',
              style: const TextStyle(fontSize: 22),
            ),
          ),
      ],
    );
    if (emoji != null && mounted) await _toggle(emoji);
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _open,
    ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .72,
      ),
      child: Wrap(
        spacing: 4,
        children: [
          for (final emoji in messageReactionEmojis)
            if ((_counts[emoji] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ActionChip(
                  label: Text('$emoji ${_counts[emoji]}'),
                  tooltip: _selected.contains(emoji)
                      ? 'Remove $emoji reaction'
                      : 'React $emoji',
                  backgroundColor: _selected.contains(emoji)
                      ? const Color(0xFFE6F2E9)
                      : null,
                  onPressed: _busy ? null : () => _toggle(emoji),
                ),
              ),
        ],
      ),
    ),
  );
}
