import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../models/document.dart';
import 'image_overlay_painter.dart';

class PdfViewerWidget extends StatelessWidget {
  final Uint8List pdfBytes;
  final PdfViewerController pdfController;
  final PdfTextSearchResult searchResult;
  final List<ImageData> globalImages;
  final bool visualizationMode;
  final double screenHeight;

  const PdfViewerWidget({
    super.key,
    required this.pdfBytes,
    required this.pdfController,
    required this.searchResult,
    required this.globalImages,
    required this.visualizationMode,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SfPdfViewer.memory(
          pdfBytes,
          controller: pdfController,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          enableDoubleTapZooming: true,
          initialZoomLevel: 0.0,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          currentSearchTextHighlightColor: Colors.yellow.withOpacity(0.8),
          otherSearchTextHighlightColor: Colors.yellow.withOpacity(0.4),
        ),
        if (globalImages.isNotEmpty && visualizationMode)
          Positioned.fill(
            child: CustomPaint(
              painter: ImageOverlayPainter(
                globalImages,
                screenHeight,
                792,  // Asume default PDF height; usa document si passed
              ),
            ),
          ),
      ],
    );
  }
}
