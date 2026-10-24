import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'workshop_gallery.dart';
import '../../../backend/db/supabase_database.dart';
import '../../home_page/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/page_refresh_state.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import 'site_policy_content.dart';

const sitePageTitles = {
  'about': 'About',
  'support': 'Support',
  'privacy': 'Privacy',
  'safety': 'Safety',
};

class SiteInformationPage extends StatefulWidget {
  const SiteInformationPage({
    super.key,
    required this.page,
    this.embedded = false,
  });
  final String page;
  final bool embedded;
  @override
  State<SiteInformationPage> createState() => _SiteInformationPageState();
}

class _SiteInformationPageState extends State<SiteInformationPage> {
  Route<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route) return;
    _route = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || route == null) return;
      PageRefreshState.remember(context, {'kind': widget.page});
      if (SupabaseDatabase.instance.client.auth.currentSession == null) {
        DesktopShellScope.of(context)?.clear();
        desktopRouteObserver.registerStandalone(route, true);
      }
    });
  }

  @override
  void dispose() {
    final route = _route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null) desktopRouteObserver.registerStandalone(route, false);
    });
    super.dispose();
  }

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF24543C),
      ),
    ),
  );
  Widget paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SelectableText(
      text,
      style: const TextStyle(
        fontSize: 16,
        height: 1.75,
        color: Color(0xFF526158),
      ),
    ),
  );
  Widget placeholder(String label, {double height = 210}) => Semantics(
    label: '$label image placeholder',
    child: Container(
      height: height,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E5D9)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 34, color: Color(0xFF5CAF78)),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text(
            'Image to be provided',
            style: TextStyle(color: Color(0xFF667269)),
          ),
        ],
      ),
    ),
  );
  Widget contact() => Container(
    padding: const EdgeInsets.all(24),
    margin: const EdgeInsets.only(top: 24),
    decoration: BoxDecoration(
      color: const Color(0xFFEDF5EE),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Get in touch',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            final sent = await launchUrl(
              Uri(scheme: 'mailto', path: 'support@junejournal.org'),
            );
            if (!sent && mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Email support@junejournal.org using your preferred email app.',
                  ),
                ),
              );
          },
          icon: const Icon(Icons.mail_outline),
          label: const Text('support@junejournal.org'),
        ),
        const SelectableText(
          'Please do not include passwords or sensitive personal information.',
        ),
      ],
    ),
  );

  Widget aboutPhoto(String asset, String label, {bool portrait = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: portrait ? 280 : 640),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: portrait ? 1 : 1541 / 1170,
                child: Image.asset(
                  'assets/about/$asset',
                  fit: portrait ? BoxFit.cover : BoxFit.contain,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
      );

  List<Widget> about() => [
    paragraph(
      'A place to document sustainability projects, learn together, and understand the impact of what we create.',
    ),
    const WorkshopGallery(featured: true),
    heading('Our Story'),
    paragraph(
      "The project began at the University of Wisconsin-Madison through the Wisconsin Idea Fellowship and is now focused in Chicago, where schools lack key tools to support climate education despite a statewide instruction mandate beginning in 2026-2027.",
    ),
    paragraph(
      "At Juniper Journal, we are dedicated to spreading awareness about the lack of environmental education resources for students and young learners.",
    ),
    paragraph(
      "Since 2020, the platform has engaged more than 600 youth and educators across the Midwest and has raised \$14,000 in pre-seed funding through startup grants and pitch competitions.",
    ),
    heading('Our Purpose'),
    paragraph(
      "As climate change disrupts weather patterns, ecosystems, and communities, young people need meaningful opportunities to understand these challenges and take action. Yet many learners lack hands-on environmental education, and sustainability projects often lack simple tools to measure and share their impact.",
    ),
    paragraph(
      "The Juniper Journal connects practical learning with shared knowledge. Our digital platform helps people document sustainability projects, track their environmental impact, and learn from one another through a global, peer-to-peer project database. Through in-person workshops, we bring sustainability, climate science, engineering, design thinking, and collaboration to life with accessible activities that spark curiosity and build practical skills.",
    ),
    paragraph(
      "Together, the platform and workshops help turn learning into measurable action. Project contributions build a growing collection of environmental impact data, showing where progress is happening and where communities need more support.",
    ),
    const WorkshopGallery(),
    const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Text(
        'All photos on this page were taken with permission.',
        style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF667269)),
      ),
    ),
    heading('Our Inspiration'),
    aboutPhoto('family.jpg', 'Chae Lee and Mee Vaj working in the fields'),
    paragraph(
      'Chae Lee (Left) and Mee Vaj (Right), Sisters, Pictured Working in the Fields.',
    ),
    paragraph(
      'Mee Vaj, grandmother of Amelia and Ben Yang, was a Hmong refugee displaced from Laos and Thailand during the Vietnam War. After immigrating to the United States, she built a life rooted in sustainability and urban farming. Her resilience continues to inspire Juniper Journal’s work with youth and communities.',
    ),
    heading('The people behind Juniper'),
    LayoutBuilder(
      builder: (context, c) {
        final benDetails = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            aboutPhoto('ben-yang.jpg', 'Ben Yang', portrait: true),
            const Text(
              'Ben Yang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            paragraph(
              'Co-Founder · CEO\nB.S. Civil Engineering, UW–Madison\u00a0’23',
            ),
          ],
        );
        final ameliaDetails = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            aboutPhoto('amelia-yang.jpg', 'Amelia Yang', portrait: true),
            const Text(
              'Amelia Yang',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            paragraph(
              'Co-Founder\nB.S. Design Engineering, Stanford\u00a0’25\nPost-Baccalaureate Premedical Program, Johns\u00a0Hopkins\u00a0’26',
            ),
          ],
        );
        final benBio = paragraph(
          'Ben is an Energy Engineer in Chicago and an environmental educator. His experience building aquaponics, hydroponics, and renewable-energy demonstrations shapes Juniper Journal’s hands-on approach to sustainability learning.',
        );
        final ameliaBio = paragraph(
          'Amelia brings a Stanford design engineering background and experience in user research and prototyping. She combines human-centered design and storytelling to make complex ideas accessible, with an interest in healthcare innovation.',
        );
        if (c.maxWidth <= 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              benDetails,
              benBio,
              const SizedBox(height: 24),
              ameliaDetails,
              ameliaBio,
            ],
          );
        }
        return Table(
          columnWidths: const {1: FixedColumnWidth(24)},
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              children: [benDetails, const SizedBox.shrink(), ameliaDetails],
            ),
            TableRow(children: [benBio, const SizedBox.shrink(), ameliaBio]),
          ],
        );
      },
    ),
  ];
  List<Widget> support() => [
    paragraph(
      'Find answers about your account, projects, and journal entries—or get in touch with us.',
    ),
    heading('Common questions'),
    for (final item in const [
      [
        'Do I need an account to explore?',
        'You can browse public projects, entries, and communities without an account. Sign in to create projects or participate.',
      ],
      [
        'How do I create a project?',
        'Sign in, choose Create, and follow the project setup steps.',
      ],
      [
        'How do I add a journal entry?',
        'Choose Create and select a journal entry, then choose the project it belongs to.',
      ],
      [
        'Can I collaborate with others?',
        'Project owners and authorized collaborators can invite people and manage collaboration from the project’s collaboration settings.',
      ],
      [
        'My projects are not loading. What should I try?',
        'Check your internet connection, wait a moment, and try again. If the problem continues, email support with the page URL, what you expected, and what happened.',
      ],
      [
        'I cannot log in. What can I do?',
        'Double-check your email or username and password. Use the password reset option if needed.',
      ],
      [
        'Who can see my projects?',
        'Visibility settings determine who can access your content. Public projects are viewable by visitors; private content remains restricted to authorized users.',
      ],
      [
        'How do I request account deletion or access to my data?',
        'Email support@junejournal.org with your request. Never send your password.',
      ],
    ])
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          item[0],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF24543C),
          ),
        ),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE0E7E2))),
        collapsedShape: const Border(
          bottom: BorderSide(color: Color(0xFFE0E7E2)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              item[1],
              style: const TextStyle(
                fontSize: 16,
                height: 1.75,
                fontWeight: FontWeight.w400,
                color: Color(0xFF59636A),
              ),
            ),
          ),
        ],
      ),
    contact(),
  ];
  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    if (!widget.embedded &&
        SupabaseDatabase.instance.client.auth.currentSession != null) {
      return HomeShellScreen(informationPage: page, restoreJournal: false);
    }
    final policy = sitePolicyContent[page];
    final title = switch (page) {
      'about' => 'Learning becomes action.\nAction becomes legacy.',
      'support' => 'A little help to keep growing.',
      'privacy' => 'Your work. Your choices.',
      _ => 'Grow a thoughtful community.',
    };
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageScrollWithFooter(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: page == 'about' ? 1280 : 940,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (sitePageTitles[page] ?? page).toUpperCase(),
                        style: const TextStyle(
                          letterSpacing: 2,
                          fontSize: 12,
                          color: Color(0xFF667269),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: MediaQuery.sizeOf(context).width < 600
                              ? 32
                              : 42,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF24543C),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (page == 'about')
                        ...about()
                      else if (page == 'support')
                        ...support()
                      else if (policy != null) ...[
                        for (final text in policy)
                          if (text.length < 65 &&
                              !text.startsWith('Last updated') &&
                              !text.contains('@') &&
                              !text.endsWith('.'))
                            heading(text)
                          else
                            paragraph(text),
                        contact(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

/// Pages retain a footer when rendered independently; the app frame supplies
/// one shared footer when a navigator is hosted inside it.
class SiteFooterScope extends InheritedWidget {
  const SiteFooterScope({super.key, required super.child});
  @override
  bool updateShouldNotify(SiteFooterScope oldWidget) => false;
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, this.onNavigate, this.compact = false});
  final ValueChanged<String>? onNavigate;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    if (onNavigate == null &&
        context.dependOnInheritedWidgetOfExactType<SiteFooterScope>() != null)
      return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: compact ? 0 : 36),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 8 : 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8EDE8))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          if (!compact || MediaQuery.sizeOf(context).width >= 700)
            const Text(
              'Juniper Journal · Learn. Create. Grow.',
              style: TextStyle(color: Color(0xFF667269)),
            ),
          Wrap(
            children: [
              for (final entry in sitePageTitles.entries)
                TextButton(
                  onPressed: () {
                    if (PageRefreshState.currentDestination?['kind'] ==
                        entry.key)
                      return;
                    if (onNavigate != null) {
                      onNavigate!(entry.key);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SiteInformationPage(page: entry.key),
                      ),
                    );
                  },
                  child: Text(entry.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
