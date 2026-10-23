import 'package:flutter/material.dart';
import 'explore_page.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key, this.browseKey});
  final GlobalKey<ProjectBrowsePageState>? browseKey;
  @override
  Widget build(BuildContext context) =>
      ProjectBrowsePage(key: browseKey, library: true);
}
