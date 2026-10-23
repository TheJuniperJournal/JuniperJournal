import 'dart:convert';
import 'package:flutter/material.dart';
import 'evidence_media_source.dart';

const _storagePrefix = 'journal-storage:';

/// Keeps storage references intact so private/expired media can be signed at display time.
List<String> journalPreviewImageSources(List<dynamic> content) {
  final sources = <String>{};
  void image(Map data) {
    String first(List<String> keys) => keys
        .map((k) => data[k]?.toString().trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final path = first(['storage_path', 'storagePath', 'path']);
    final url = first([
      'public_url',
      'publicUrl',
      'url',
      'signed_url',
      'signedUrl',
      'image_url',
      'imageUrl',
    ]);
    if (path.isNotEmpty && !path.startsWith('http')) {
      sources.add(
        '$_storagePrefix${jsonEncode({...Map<String, dynamic>.from(data), 'storage_path': path})}',
      );
    } else if (url.isNotEmpty || path.isNotEmpty) {
      sources.add(url.isNotEmpty ? url : path);
    }
  }

  void walk(dynamic node) {
    if (node is Map) {
      final type = node['type']?.toString().toLowerCase();
      if (type == 'image') {
        image(node['data'] is Map ? node['data'] as Map : node);
      }
      if (node['images'] is List) {
        for (final item in node['images'] as List) {
          if (item is Map) image(item);
          if (item is String && item.startsWith('http')) sources.add(item);
        }
      }
      if (node['contentType']?.toString().startsWith('image/') == true ||
          node['content_type']?.toString().startsWith('image/') == true)
        image(node);
      for (final value in node.values) {
        walk(value);
      }
    } else if (node is List) {
      for (final value in node) {
        walk(value);
      }
    }
  }

  walk(content);
  return sources.toList();
}

/// A journal photo takes priority; a project cover represents entries without one.
String? journalFeedPreviewImage(List<dynamic> content, {String? projectCover}) {
  final images = journalPreviewImageSources(content);
  if (images.isNotEmpty) return images.first;
  return projectCover?.trim().isNotEmpty == true ? projectCover!.trim() : null;
}

class JournalPreviewImage extends StatelessWidget {
  const JournalPreviewImage(this.source, {super.key, this.fit = BoxFit.cover});
  final String source;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    if (source.startsWith(_storagePrefix)) {
      final data = Map<String, dynamic>.from(
        jsonDecode(source.substring(_storagePrefix.length)) as Map,
      );
      return SavedEvidenceImage(
        key: ValueKey(source),
        source: data,
        bucket: data['bucket']?.toString() ?? 'images',
        fit: fit,
      );
    }
    return Image.network(
      source,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
