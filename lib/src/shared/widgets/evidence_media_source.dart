import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:flutter/material.dart';
import '../../backend/storage/storage_service.dart';

typedef EvidenceUrlSigner = Future<String> Function(String path, String bucket);

/// Resolves saved storage references and both current and older URL field names.
Future<String> resolveEvidenceMediaUrl(
  Map<dynamic, dynamic> data, {
  required String bucket,
  EvidenceUrlSigner? signer,
}) async {
  String first(List<String> keys) => keys
      .map((key) => data[key]?.toString().trim() ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final direct = first([
    'public_url',
    'publicUrl',
    'signed_url',
    'signedUrl',
    'url',
  ]);
  final path = first(['storage_path', 'storagePath']);
  if (path.startsWith('https://') || path.startsWith('http://')) return path;
  if (path.isNotEmpty) {
    try {
      return await (signer ??
          (path, bucket) => StorageService().createSignedUrl(
            path,
            bucketName: bucket,
          ))(path, bucket);
    } catch (_) {
      if (direct.isEmpty) rethrow;
    }
  }
  return direct;
}

/// Saved images used inside sketches and other evidence previews.
class SavedEvidenceImage extends StatefulWidget {
  const SavedEvidenceImage({
    super.key,
    required this.source,
    this.bucket = 'images',
    this.fit = BoxFit.cover,
  });
  final Map<String, dynamic> source;
  final String bucket;
  final BoxFit fit;
  @override
  State<SavedEvidenceImage> createState() => _SavedEvidenceImageState();
}

class _SavedEvidenceImageState extends State<SavedEvidenceImage> {
  late final Future<String> _url = resolveEvidenceMediaUrl(
    widget.source,
    bucket: widget.bucket,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError || snapshot.data?.isNotEmpty != true)
        return const Center(child: Icon(Icons.image_not_supported_outlined));
      return ProtectedImage.network(
        snapshot.data!,
        fit: widget.fit,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    },
  );
}
