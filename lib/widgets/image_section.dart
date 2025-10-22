import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/document.dart';

class ImageSection extends StatelessWidget {
  final List<ImageData> images;
  final bool showImages;
  final TextAlign textAlign;
  final bool isDesktop;
  final VoidCallback? onToggle; // Opcional callback para toggle

  const ImageSection({
    super.key,
    required this.images,
    required this.showImages,
    required this.textAlign,
    required this.isDesktop,
    this.onToggle,
  });

  Uint8List? _extractBase64(String dataUri) {
    final trimmedUri = dataUri.trim();
    final match = RegExp(r'data:image/[^;]+;base64,(.+)').firstMatch(trimmedUri);
    if (match != null && match.group(1) != null) {
      try {
        return base64Decode(match.group(1)!);
      } catch (e) {
        debugPrint('Data URI error: $e');
      }
    }
    try {
      return base64Decode(trimmedUri);
    } catch (e) {
      debugPrint('Base64 error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!showImages || images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: images.asMap().entries.map((entry) {
        final imgData = entry.value;
        final bytes = _extractBase64(imgData.data ?? '');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: isDesktop ? 350 : 250,
              maxWidth: double.infinity,
            ),
            child: bytes != null && bytes.isNotEmpty
                ? Image.memory(
              bytes,
              fit: BoxFit.contain,
              key: ValueKey('img_${entry.key}'),
              errorBuilder: (c, e, st) => Container(
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image),
              ),
            )
                : Container(
              height: 60,
              color: Colors.grey[200],
              child: Text(
                'Error: ${imgData.extension ?? 'N/A'}',
                style: const TextStyle(color: Colors.red, fontSize: 11),
                textAlign: textAlign,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
