import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../models/document.dart';

class ImageOverlayPainter extends CustomPainter {
  final List<ImageData> images;
  final double screenHeight;
  final double pdfHeight;

  ImageOverlayPainter(this.images, this.screenHeight, this.pdfHeight);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final scaleY = screenHeight / pdfHeight;
    for (var img in images) {
      final pos = img.position;
      final offsetX = pos['x']!.toDouble() / 100 * size.width;
      final offsetY = pos['y']!.toDouble() / 100 * size.height * scaleY;
      final relWidth = pos['width']!.toDouble() / 100 * size.width;
      final relHeight = pos['height']!.toDouble() / 100 * size.height * scaleY;

      final rect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(offsetX, offsetY, relWidth, relHeight),
        const ui.Radius.circular(4),
      );
      canvas.drawRRect(rect, ui.Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
