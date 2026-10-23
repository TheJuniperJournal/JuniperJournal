import 'package:flutter/material.dart';
import '../../../shared/widgets/create_menu_dialog.dart';

enum CommunityCreateAction { project, journal }

class CommunityCreateMenu extends StatelessWidget {
  const CommunityCreateMenu({super.key, required this.communityName});
  final String communityName;

  @override
  Widget build(BuildContext context) => CreateMenuDialog(
    communityName: communityName,
    onClose: () => Navigator.pop(context),
    onProjectTap: () => Navigator.pop(context, CommunityCreateAction.project),
    onJournalTap: () => Navigator.pop(context, CommunityCreateAction.journal),
  );
}
