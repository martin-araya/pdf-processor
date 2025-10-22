import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';  // Para debugPrint
import 'package:flutter/material.dart';
import '../services/document_service.dart' as document_service;  // Para getImage
import '../models/document.dart';  // ImageData

class ImageGallery extends StatefulWidget {
  final String docId;  // Nuevo: Requerido para endpoint /documents/{docId}/images/{imageId}
  final List<String> imageIds;

  const ImageGallery({
    super.key,
    required this.docId,
    required this.imageIds,
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  final Map<String, ImageData> _loadedImages = {};
  final Map<String, bool> _loading = {};

  @override
  void initState() {
    super.initState();
    _loadAllImages();
  }

  Future<void> _loadAllImages() async {
    for (final imageId in widget.imageIds) {
      if (!_loadedImages.containsKey(imageId)) {
        _loadImage(imageId);
      }
    }
    if (mounted) setState(() {});  // Trigger rebuild post-init si needed
  }

  Future<void> _loadImage(String imageId) async {
    if (_loading[imageId] == true) return;  // Avoid duplicate loads
    if (!mounted) return;
    setState(() => _loading[imageId] = true);

    try {
      final imageData = await document_service.DocumentService.getImage(widget.docId, imageId);
      if (mounted) {
        setState(() {
          _loadedImages[imageId] = imageData as ImageData;
          _loading[imageId] = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading image $imageId: $e');
      if (mounted) {
        setState(() => _loading[imageId] = false);
      }
    }
  }

  void _showFullImage(BuildContext context, ImageData imageData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullImageView(imageData: imageData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imágenes (${widget.imageIds.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: widget.imageIds.length,
          itemBuilder: (context, index) {
            final imageId = widget.imageIds[index];
            final isLoading = _loading[imageId] ?? false;
            final imageData = _loadedImages[imageId];

            return _ImageThumbnail(
              imageId: imageId,
              imageData: imageData,
              isLoading: isLoading,
              onTap: imageData != null
                  ? () => _showFullImage(context, imageData)
                  : null,
            );
          },
        ),
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String imageId;
  final ImageData? imageData;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ImageThumbnail({
    required this.imageId,
    required this.imageData,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = imageData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha((0.2 * 255).round()),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : data != null
              ? Stack(
            fit: StackFit.expand,
            children: [
              (data.data?.isNotEmpty == true)
                  ? Image.memory(
                base64Decode(data.data!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.error,
                    ),
                  );
                },
              )
                  : Center(
                child: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
              ),
              // Overlay para indicar que es clickeable
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.zoom_in,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          )
              : Center(
            child: Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullImageView extends StatelessWidget {
  final ImageData imageData;

  const _FullImageView({required this.imageData});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (imageData.data?.isNotEmpty == true) {
      try {
        bytes = base64Decode(imageData.data!);
      } catch (e) {
        debugPrint('Full view decode error: $e');
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Imagen (${imageData.extension ?? 'N/A'})',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidad de descarga no implementada'),
                ),
              );
            },
          ),
        ],
      ),
      body: bytes != null && bytes.isNotEmpty
          ? Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar la imagen',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar la imagen',
              style: TextStyle(
                color: Colors.white.withAlpha((0.7 * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
