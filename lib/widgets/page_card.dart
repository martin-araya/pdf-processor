import 'package:flutter/foundation.dart' show debugPrint;  // Para debugPrint
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Para Clipboard
import '../models/document.dart';
import '../services/document_service.dart' as document_service;  // Para getImage
import 'page_header.dart';
import 'text_renderer.dart';
import 'image_section.dart';  // Asume este widget usa List<ImageData>, sin docId

class PageCard extends StatefulWidget {
  final PageData page;
  final String documentId;  // Ya pasado, usa para images
  final int index;
  final String searchQuery;
  final TextAlign? textAlign;
  final bool continuousView;

  const PageCard({
    super.key,
    required this.page,
    required this.documentId,
    required this.index,
    this.searchQuery = '',
    this.textAlign,
    this.continuousView = false,
  });

  @override
  State<PageCard> createState() => _PageCardState();
}

class _PageCardState extends State<PageCard> {
  bool _showImages = true;
  List<ImageData> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final imageIds = widget.page.imageIds ?? <String>[];
    if (imageIds.isEmpty) return;
    try {
      final images = <ImageData>[];
      for (final id in imageIds) {
        final response = await document_service.DocumentService.getImage(widget.documentId, id);
        final imageData = ImageData.fromJson(response);  // Asume fromJson en model
        images.add(imageData);
      }
      if (mounted) {
        setState(() => _images = images);
      }
    } catch (e) {
      debugPrint('Error loading images for page ${widget.index + 1}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error cargando imágenes')),
        );
      }
    }
  }

  void _copyText() {
    final safeText = widget.page.text ?? '';
    Clipboard.setData(ClipboardData(text: safeText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Copiado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final fontSize = isDesktop ? 15.0 : 13.0;
    final safeText = widget.page.text ?? '';
    final hasImages = _images.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 300, maxWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  index: widget.index,
                  continuousView: widget.continuousView,
                  hasText: safeText.isNotEmpty,
                  hasImages: hasImages,
                  showImages: _showImages,
                  onCopy: _copyText,
                  onToggleImages: () => setState(() => _showImages = !_showImages),
                ),
                const SizedBox(height: 6),
                if (safeText.isNotEmpty)
                  TextRenderer(
                    text: safeText,
                    searchQuery: widget.searchQuery,
                    textAlign: widget.textAlign ?? TextAlign.start,
                    fontSize: fontSize,
                    index: widget.index,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Sin texto',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
                      textAlign: widget.textAlign ?? TextAlign.start,
                    ),
                  ),
                ImageSection(
                  images: _images,
                  showImages: _showImages,
                  textAlign: widget.textAlign ?? TextAlign.start,
                  isDesktop: isDesktop,
                  onToggle: () => setState(() => _showImages = !_showImages),
                  // docId: widget.documentId,  // Removido; agrega en ImageSection si needed (e.g., para Gallery)
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
