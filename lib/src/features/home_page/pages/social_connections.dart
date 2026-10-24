import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/features/home_page/pages/public_user_profile.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';

enum ConnectionsTab { friends, followers }

class SocialConnectionsPage extends StatefulWidget {
  final List<UserProfile> friends;
  final List<UserProfile> followers;
  final ConnectionsTab initialTab;

  const SocialConnectionsPage({
    super.key,
    required this.friends,
    required this.followers,
    required this.initialTab,
  });

  @override
  State<SocialConnectionsPage> createState() => _SocialConnectionsPageState();
}

class _SocialConnectionsPageState extends State<SocialConnectionsPage> {
  final _searchController = TextEditingController();
  late ConnectionsTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserProfile> _filter(List<UserProfile> source) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;

    return source.where((item) {
      final displayName = item.displayName?.toLowerCase() ?? '';
      final username = item.username?.toLowerCase() ?? '';
      return displayName.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final source = _tab == ConnectionsTab.friends
        ? widget.friends
        : widget.followers;
    final data = _filter(source);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: AppColors.border,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tab == ConnectionsTab.friends ? 'Friends' : 'Followers',
          style: AppTypography.pageTitle,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<ConnectionsTab>(
                groupValue: _tab,
                children: {
                  ConnectionsTab.friends: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text('Friends ${widget.friends.length}'),
                  ),
                  ConnectionsTab.followers: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text('Followers ${widget.followers.length}'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _tab = value);
                },
              ),
            ),
            const SizedBox(height: AppMetrics.labelGap),
            Expanded(
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.trim().isEmpty
                            ? (_tab == ConnectionsTab.friends
                                  ? 'No friends yet.'
                                  : 'No followers yet.')
                            : 'No results found.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    )
                  : PageScrollWithFooter(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final person = data[index];
                          final userId = person.id;
                          final displayName =
                              person.displayName ?? 'Unknown User';
                          final username = person.username;
                          final avatarUrl = person.avatarUrl;

                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: Colors.white,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.avatarBackground,
                              backgroundImage:
                                  (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? NetworkImage(avatarUrl)
                                  : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      color: AppColors.avatarIcon,
                                    )
                                  : null,
                            ),
                            title: Text(displayName),
                            subtitle: username != null && username.isNotEmpty
                                ? Text('@$username')
                                : null,
                            onTap: userId.isEmpty
                                ? null
                                : () {
                                    pushAppRoute(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PublicUserProfilePage(
                                          userId: userId,
                                        ),
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
