import 'account_required_prompt.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import 'flower_reaction_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../backend/db/supabase_database.dart';
import 'modal_actions.dart';

class JournalEntryActivity extends StatefulWidget {
  const JournalEntryActivity({
    super.key,
    required this.entryId,
    this.likes = 0,
    this.comments = 0,
  });
  final String entryId;
  final int likes, comments;
  @override
  State<JournalEntryActivity> createState() => _JournalEntryActivityState();
}

class _JournalEntryActivityState extends State<JournalEntryActivity> {
  int? _likes, _comments;
  bool _liked = false, _busy = false;
  dynamic get _db => SupabaseDatabase.instance.client;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final likes = await _db
          .from('journal_entry_likes')
          .select('user_id')
          .eq('journal_entry_id', widget.entryId);
      final comments = await _db
          .from('journal_entry_comments')
          .select('id')
          .eq('journal_entry_id', widget.entryId);
      if (mounted)
        setState(() {
          _likes = (likes as List).length;
          _comments = (comments as List).length;
          _liked = likes.any(
            (row) => row['user_id'] == _db.auth.currentUser?.id,
          );
        });
    } catch (_) {
      /* Initial placeholders remain until interaction or reload. */
    }
  }

  void _error() {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this entry. Please try again.'),
        ),
      );
  }

  Future<void> _like() async {
    if (_db.auth.currentUser == null) {
      await showAccountRequiredPrompt(context);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = _db.auth.currentUser;
      if (user == null) throw StateError('Sign in required');
      if (_liked) {
        await _db
            .from('journal_entry_likes')
            .delete()
            .eq('journal_entry_id', widget.entryId)
            .eq('user_id', user.id);
      } else {
        await _db.from('journal_entry_likes').insert({
          'journal_entry_id': widget.entryId,
          'user_id': user.id,
        });
      }
      await _load();
    } catch (_) {
      _error();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openComments() async {
    if (_db.auth.currentUser == null) {
      await showAccountRequiredPrompt(context);
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => _EntryComments(entryId: widget.entryId),
    );
    await _load();
  }

  Widget _action(
    String label,
    String asset,
    int count,
    VoidCallback tap, {
    bool selected = false,
  }) => Semantics(
    button: true,
    label: label,
    selected: selected,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                asset,
                width: 21,
                height: 21,
                colorFilter: selected
                    ? const ColorFilter.mode(Color(0xFF5DB075), BlendMode.srcIn)
                    : null,
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(fontSize: 14, color: Color(0xFF717171)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _action(
          _liked ? 'Unlike journal entry' : 'Like journal entry',
          'assets/prototyping/build_flower.svg',
          _likes ?? widget.likes,
          _like,
          selected: _liked,
        ),
        const SizedBox(width: 4),
        _action(
          'Comments',
          'assets/prototyping/build_comment.svg',
          _comments ?? widget.comments,
          _openComments,
        ),
      ],
    ),
  );
}

class _EntryComments extends StatefulWidget {
  const _EntryComments({required this.entryId});
  final String entryId;
  @override
  State<_EntryComments> createState() => _EntryCommentsState();
}

class _EntryCommentsState extends State<_EntryComments> {
  final _text = ConversationController();
  List<Map<String, dynamic>>? _rows;
  bool _sending = false;
  String? _error;
  dynamic get _db => SupabaseDatabase.instance.client;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('journal_entry_comments')
          .select('id, user_id, content, created_at')
          .eq('journal_entry_id', widget.entryId)
          .order('created_at');
      final ids = (rows as List).map((r) => r['user_id']).toSet().toList();
      final profiles = ids.isEmpty
          ? []
          : await _db
                .from('profiles')
                .select('id, display_name, username')
                .inFilter('id', ids);
      if (mounted)
        setState(() {
          _rows = [
            for (final r in rows)
              {
                ...Map<String, dynamic>.from(r),
                'author':
                    (profiles as List)
                        .where((p) => p['id'] == r['user_id'])
                        .map(
                          (p) => p['display_name'] ?? p['username'] ?? 'Member',
                        )
                        .firstOrNull ??
                    'Member',
              },
          ];
          for (final row in _rows!) {
            _text.remember(row['user_id'].toString(), row['author']);
          }
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load comments. Please try again.');
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _db.from('journal_entry_comments').insert({
        'journal_entry_id': widget.entryId,
        'user_id': _db.auth.currentUser.id,
        'content': _text.payload,
      });
      _text.clear();
      await _load();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not post your comment. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Comments',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Close comments',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _rows == null && _error == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        if (_rows?.isEmpty == true)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No comments yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final row in _rows ?? <Map<String, dynamic>>[])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row['author'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ConversationBody(row['content']),
                                TextButton(
                                  onPressed: () => _text.replyTo(
                                    row['id'].toString(),
                                    row['author'],
                                    row['content'],
                                  ),
                                  child: const Text('Reply'),
                                ),
                                FlowerReactionButton(
                                  target: FlowerTarget.journalComment,
                                  targetId: row['id'].toString(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            ConversationComposer(
              controller: _text,
              child: TextField(
                controller: _text,
                focusNode: _text.focusNode,
                enabled: !_sending,
                minLines: 5,
                maxLines: null,
                maxLength: 5000,
                decoration: const InputDecoration(
                  hintText: 'Write a comment…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Posting…' : 'Comment'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
