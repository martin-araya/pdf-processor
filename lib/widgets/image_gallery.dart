import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/document.dart';

class ImageGallery extends StatefulWidget {
  final List<String> imageIds;

  const ImageGallery({super.key, required this.imageIds});

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  final ApiService _api = ApiService();
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
  }

  Future<void> _loadImage(String imageId) async {
    setState(() => _loading[imageId] = true);

    try {
      final imageData = await _api.getImage(imageId);
      if (mounted) {
        setState(() {
          _loadedImages[imageId] = imageData as ImageData;
          _loading[imageId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading[imageId] = false);
      }
      debugPrint('Error loading image $imageId: $e');
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

    // Capturar imageData en una variable local no-nullable si existe
    final data = imageData;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
              Image.memory(
                base64Decode(data.data),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.error,
                    ),
                  );
                },
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
    final Uint8List bytes = base64Decode(imageData.data);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Imagen (${imageData.extension})',
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
      body: Center(
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
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}