import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../models/document.dart';
import '../services/api_service.dart';

class PageContent extends StatefulWidget {
  final PageData page;
  final String documentId;
  final int index;

  const PageContent({
    super.key,
    required this.page,
    required this.documentId,
    required this.index,
  });

  @override
  State<PageContent> createState() => _PageContentState();
}

class _PageContentState extends State<PageContent> {
  bool _showImages = true;
  final ApiService _api = ApiService();
  List<ImageData> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    if (widget.page.imageIds.isEmpty) return;
    try {
      final images = <ImageData>[];
      for (final id in widget.page.imageIds) {
        final imageData = await _api.getImage(id);
        images.add(imageData);
      }
      if (mounted) setState(() => _images = images);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error imgs p${widget.index + 1}: $e')));
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.page.text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Copiado')));
  }

  Uint8List? _extractBase64(String dataUri) {
    final match = RegExp(r'data:image\/[^;]+;base64,(.+)').firstMatch(dataUri.trim());
    if (match?.group(1) != null) {
      try {
        return base64Decode(match!.group(1)!);
      } catch (e) {
        debugPrint('Data URI error: $e');
      }
    }
    try {
      return base64Decode(dataUri.trim());
    } catch (e) {
      debugPrint('Base64 error: $e');
    }
    return null;
  }

  List<InlineSpan> _buildTextSpans(double fontSize) {
    final paragraphs = (widget.page.text ?? '').split('\n\n');
    return paragraphs.map((p) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) return const TextSpan(text: '\n\n');
      return TextSpan(
        text: trimmed + '\n\n',
        style: GoogleFonts.lora(fontSize: fontSize, height: 1.4, color: Theme.of(context).colorScheme.onSurface),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final fontSize = isDesktop ? 14.0 : 12.0;
    final hasImages = _images.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número página sutil (top)
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('P${widget.index + 1}', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
            ),
          ),
          const SizedBox(height: 8),
          // Botones (copiar y toggle imgs, si aplica)
          Row(
            children: [
              if ((widget.page.text ?? '').isNotEmpty)
                OutlinedButton.icon(onPressed: _copyText, icon: const Icon(Icons.copy, size: 14), label: const Text('Copiar', style: TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              if (hasImages)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showImages = !_showImages),
                  icon: Icon(_showImages ? Icons.visibility_off : Icons.visibility, size: 14),
                  label: Text(_showImages ? 'Ocultar' : 'Imgs', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Texto principal
          if ((widget.page.text ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: RichText(text: TextSpan(children: _buildTextSpans(fontSize)), textAlign: TextAlign.justify),
            )
          else
            const Text('Sin texto', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          // Imágenes inline (ordenadas por ID, full width o fitted)
          if (_showImages && hasImages)
            ..._images.map((imgData) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FutureBuilder<Uint8List?>(
                future: Future.value(_extractBase64(imgData.data ?? '')),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
                  final bytes = snapshot.data;
                  if (bytes != null && bytes.isNotEmpty) {
                    return Image.memory(bytes, fit: BoxFit.contain, errorBuilder: (c, e, st) => Container(height: 80, color: Colors.grey[200], child: const Icon(Icons.broken_image)));
                  }
                  return Container(height: 80, color: Colors.grey[200], child: Text('Error: ${imgData.extension ?? 'N/A'}', style: const TextStyle(color: Colors.red)));
                },
              ),
            )),
        ],
      ),
    );
  }
}
