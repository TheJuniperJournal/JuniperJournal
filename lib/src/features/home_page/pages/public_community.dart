import 'package:flutter/material.dart';
import '../../../backend/db/models/community.dart';
import '../../community/pages/community_home_screen.dart';

class PublicCommunityScreen extends StatelessWidget {
  const PublicCommunityScreen({super.key, required this.community});
  final Community community;
  @override
  Widget build(BuildContext context) =>
      CommunityHomeScreen(community: community);
}
