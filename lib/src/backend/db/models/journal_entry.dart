class JournalEntry {
  final double ecoPoints;
  final String id;
  final String title;
  final List<dynamic> content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String projectId;
  final String? progress;
  final List<String> tags;
  final String? authorId;
  final String? authorAvatarUrl;
  final String? authorDisplayName;

  bool get isFreeNotes =>
      content.whereType<Map>().any((row) => row['stage'] == 'free_notes');

  /// The chosen prototyping journal type, independent of its development phase.
  String? get prototypingTypeLabel {
    for (final block in content.whereType<Map>()) {
      if (block['stage'] != 'prototyping') continue;
      return switch (block['entryType']) {
        'building' => 'Building',
        'testing' => 'Testing',
        'technical_analysis' => 'Technical Analysis',
        _ => null,
      };
    }
    return null;
  }

  const JournalEntry({
    required this.id,
    this.ecoPoints = 0,
    required this.title,
    required this.content,
    required this.projectId,
    this.createdAt,
    this.updatedAt,
    this.progress,
    this.tags = const [],
    this.authorId,
    this.authorAvatarUrl,
    this.authorDisplayName,
  });

  Set<String> get participantIds {
    final ids = <String>{};
    void walk(dynamic node) {
      if (node is Map) {
        for (final pair in node.entries) {
          if (['involved', 'involvedIds', 'involved_ids'].contains(pair.key) &&
              pair.value is List) {
            for (final person in pair.value as List) {
              final id = person is Map
                  ? (person['id'] ?? person['user_id'])?.toString()
                  : person?.toString();
              if (id != null && id.isNotEmpty) ids.add(id);
            }
          } else {
            walk(pair.value);
          }
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(content);
    return ids;
  }

  /// Only explicitly selected involvement contributes; project membership does not.
  int get contributorCount {
    final people = <String>{};
    void add(dynamic person) {
      final id = person is Map
          ? (person['id'] ?? person['user_id'])?.toString().trim()
          : person?.toString().trim();
      final name = person is Map ? person['name']?.toString().trim() : null;
      if ((id != null && id == authorId) ||
          ((id == null || id.isEmpty) &&
              name != null &&
              name == authorDisplayName)) {
        return;
      }
      if (id != null && id.isNotEmpty) {
        people.add(id);
      } else if (name != null && name.isNotEmpty) {
        people.add('name:${name.toLowerCase()}');
      }
    }

    void walk(dynamic node) {
      if (node is Map) {
        for (final entry in node.entries) {
          if (['involved', 'involvedIds', 'involved_ids'].contains(entry.key) &&
              entry.value is List) {
            for (final person in entry.value as List) {
              add(person);
            }
          } else {
            walk(entry.value);
          }
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(content);
    return people.length;
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return JournalEntry(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content'] is List
          ? map['content'] as List<dynamic>
          : const [],
      ecoPoints: (map['eco_points'] as num? ?? 0).toDouble(),
      projectId: map['project_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      progress: map['progress']?.toString(),
      tags: map['tags'] is List
          ? List<String>.from((map['tags'] as List).map((t) => t.toString()))
          : const [],
      authorId: map['user_id']?.toString(),
      authorAvatarUrl: profile?['avatar_url']?.toString(),
      authorDisplayName:
          profile?['display_name']?.toString() ??
          profile?['username']?.toString(),
    );
  }
}
