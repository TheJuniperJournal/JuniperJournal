import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// XFile bytes work in browsers and native apps; no filesystem dependency.
class PickedImagePreview extends StatefulWidget {
  const PickedImagePreview({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
  });
  final XFile file;
  final BoxFit fit;
  @override
  State<PickedImagePreview> createState() => _PickedImagePreviewState();
}

class _PickedImagePreviewState extends State<PickedImagePreview> {
  late Future<Uint8List> _bytes = widget.file.readAsBytes();
  @override
  void didUpdateWidget(covariant PickedImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return const Center(child: Icon(Icons.broken_image_outlined));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      return Image.memory(
        snapshot.data!,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    },
  );
}
