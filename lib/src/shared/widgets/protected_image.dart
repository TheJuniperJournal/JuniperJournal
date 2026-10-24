import 'dart:async';
import 'package:flutter/material.dart';
import '../../backend/db/supabase_database.dart';

/// Private storage references stay stable in saved content. Authorization is
/// checked when displayed; expiring signed URLs never become the saved source.
String? journalAttachmentPath(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  final parts = uri.pathSegments;
  final index = parts.indexOf('journal-attachments');
  if (index < 3 ||
      index + 1 >= parts.length ||
      parts[index - 2] != 'object' ||
      parts[index - 3] != 'v1')
    return null;
  return parts.skip(index + 1).join('/');
}

Future<String> authorizedMediaUrl(String value) async {
  final path = journalAttachmentPath(value);
  if (path == null) return value;
  final client = SupabaseDatabase.instance.client;
  // Only sign references belonging to this backend, never an arbitrary host.
  final expected = Uri.parse(
    client.storage.from('journal-attachments').getPublicUrl(path),
  );
  if (Uri.parse(value).origin != expected.origin) return value;
  return client.storage.from('journal-attachments').createSignedUrl(path, 3600);
}

class ProtectedImage extends StatefulWidget {
  const ProtectedImage.network(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });
  final String src;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  @override
  State<ProtectedImage> createState() => _ProtectedImageState();
}

class _ProtectedImageState extends State<ProtectedImage> {
  Future<String>? _url;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProtectedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) _load();
  }

  void _load() {
    _refresh?.cancel();
    if (journalAttachmentPath(widget.src) == null) {
      _url = null;
      return;
    }
    _url = authorizedMediaUrl(widget.src);
    _refresh = Timer(const Duration(minutes: 55), () {
      if (mounted) setState(_load);
    });
  }

  Widget _image(String src) => Image.network(
    src,
    width: widget.width,
    height: widget.height,
    fit: widget.fit,
    errorBuilder: widget.errorBuilder,
    loadingBuilder: widget.loadingBuilder,
  );
  @override
  Widget build(BuildContext context) {
    if (_url == null) return _image(widget.src);
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return widget.errorBuilder?.call(
                context,
                snapshot.error!,
                StackTrace.empty,
              ) ??
              SizedBox(
                width: widget.width,
                height: widget.height,
                child: const Icon(Icons.image_not_supported_outlined),
              );
        if (!snapshot.hasData)
          return SizedBox(width: widget.width, height: widget.height);
        return _image(snapshot.data!);
      },
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }
}
