class Project {
  final bool shareFriends;
  final List<String> sharedCommunityIds;
  final String projectType;
  final List<Map<String, dynamic>> communityLinks;
  final List<Map<String, dynamic>> learningObjectives;
  final String id;
  final String projectName;
  final List<String> tags;
  final String? imageUrl;
  final String? userId;
  final DateTime? createdAt;
  final String? problemStatement;
  final int likes;
  final String? difficulty;
  final String? subjectDomain;
  final String? progress;
  final String? projectScale;
  final String? visibility;
  final int journalEntryCount;
  final Set<String> journalProgressValues;

  const Project({
    this.shareFriends = false,
    this.sharedCommunityIds = const [],
    this.projectType = 'collaborative',
    this.communityLinks = const [],
    this.learningObjectives = const [],
    required this.id,
    required this.projectName,
    required this.tags,
    this.imageUrl,
    this.userId,
    this.createdAt,
    this.problemStatement,
    this.likes = 0,
    this.difficulty,
    this.subjectDomain,
    this.progress,
    this.projectScale,
    this.visibility,
    this.journalEntryCount = 0,
    this.journalProgressValues = const {},
  });

  factory Project.fromMap(Map<String, dynamic> map) => Project(
    shareFriends: map['share_friends'] == true,
    sharedCommunityIds: (map['shared_community_ids'] as List? ?? [])
        .map((id) => id.toString())
        .toList(),
    projectType: map['project_type']?.toString() ?? 'collaborative',
    communityLinks: (map['community_links'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(),
    learningObjectives: (map['learning_objectives'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(),
    id: map['id']?.toString() ?? '',
    projectName: map['project_name']?.toString() ?? '',
    tags: map['tags'] is List
        ? (map['tags'] as List)
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toList()
        : const [],
    imageUrl: map['project_image_url']?.toString(),
    userId: map['user_id']?.toString(),
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    problemStatement: map['problem_statement']?.toString(),
    likes: (map['likes'] as num?)?.toInt() ?? 0,
    difficulty: map['difficulty']?.toString(),
    subjectDomain: map['subject_domain']?.toString(),
    progress: map['progress']?.toString(),
    projectScale: map['project_scale']?.toString(),
    visibility: map['visibility']?.toString(),
    journalEntryCount: () {
      final entries = map['journal_entries'];
      if (entries is List && entries.isNotEmpty && entries[0] is Map) {
        // count aggregate format: [{"count": N}]
        final first = entries[0] as Map;
        if (first.containsKey('count')) return first['count'] as int? ?? 0;
        // progress format: [{progress: "..."}, ...] — count by length
        return entries.length;
      }
      return 0;
    }(),
    journalProgressValues: () {
      final entries = map['journal_entries'];
      if (entries is! List) return <String>{};
      return entries
          .whereType<Map>()
          .map((e) => e['progress']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
    }(),
  );
}
