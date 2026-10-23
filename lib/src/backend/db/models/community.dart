import 'package:flutter/material.dart';

class Community {
  final String id;
  final String name;
  final String? imageUrl;
  final String visibility;
  final String? subjectFocus;
  final String createdBy;
  final String? conversationId;
  final String? bannerColorHex;
  final DateTime? createdAt;

  const Community({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.visibility,
    this.subjectFocus,
    required this.createdBy,
    this.conversationId,
    this.bannerColorHex,
    this.createdAt,
  });

  /// Resolved banner color — falls back to dark forest green.
  Color get bannerColor {
    final hex = bannerColorHex;
    if (hex == null || hex.isEmpty) return const Color(0xFF1E4620);
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF1E4620);
    }
  }

  Community copyWith({
    String? name,
    String? imageUrl,
    String? visibility,
    String? subjectFocus,
    String? bannerColorHex,
  }) => Community(
    id: id,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    visibility: visibility ?? this.visibility,
    subjectFocus: subjectFocus ?? this.subjectFocus,
    createdBy: createdBy,
    conversationId: conversationId,
    bannerColorHex: bannerColorHex ?? this.bannerColorHex,
    createdAt: createdAt,
  );

  factory Community.fromMap(Map<String, dynamic> map) => Community(
    id: map['id']?.toString() ?? '',
    name: map['name']?.toString() ?? '',
    imageUrl: map['image_url']?.toString(),
    visibility: map['visibility']?.toString() ?? 'public',
    subjectFocus: map['subject_focus']?.toString(),
    createdBy: map['created_by']?.toString() ?? '',
    conversationId: map['conversation_id']?.toString(),
    bannerColorHex: map['banner_color']?.toString(),
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
  );
}
