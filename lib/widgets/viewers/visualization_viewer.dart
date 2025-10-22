import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../models/document.dart';
import '../table_widget.dart';

class VisualizationViewer extends StatelessWidget {
  final Document document;
  final List<Map<String, dynamic>> allTables;
  final List<ImageData> globalImages;
  final String? sortColumn;
  final String searchQuery;
  final List<int> searchResults;
  final ItemScrollController bodyScrollController;
  final TextAlign textAlign;
  final Function(String)? onSortTables;

  const VisualizationViewer({
    super.key,
    required this.document,
    required this.allTables,
    required this.globalImages,
    this.sortColumn,
    required this.searchQuery,
    required this.searchResults,
    required this.bodyScrollController,
    required this.textAlign,
    this.onSortTables,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
      itemScrollController: bodyScrollController,
      itemCount: document.pages.length,
      itemBuilder: (context, pageIdx) {
        final page = document.pages[pageIdx];
        final pageHeight = (page.dimensions.height ?? 792) * 0.6;
        final pageWidth = (page.dimensions.width ?? 612) * 0.8;
        final pageTables = page.tables ?? [];

        // FIX: Usa la propiedad real existente; si tu ImageData no tiene pageOffset,
        // puedes filtrar por algún otro criterio o no filtrar.
        final pageGlobalImages = globalImages; // sin filtro si no hay pageOffset

        return Container(
          height: pageHeight,
          width: pageWidth,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SingleChildScrollView(
                  child: Text(
                    page.text ?? '',
                    textAlign: textAlign,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              ...pageGlobalImages.map((img) {
                if (img.data.isEmpty) return const SizedBox();
                final parts = img.data.split(',');
                if (parts.length < 2) return const SizedBox();
                final bytes = base64Decode(parts[1]);
                final pos = img.position; // Map con x,y,width,height %
                return Positioned(
                  left: (pos['x'] ?? 50).toDouble() / 100 * pageWidth,
                  top: (pos['y'] ?? 30).toDouble() / 100 * pageHeight,
                  width: (pos['width'] ?? 20).toDouble() / 100 * pageWidth,
                  height: (pos['height'] ?? 15).toDouble() / 100 * pageHeight,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stk) => Container(
                      color: Colors.red.withOpacity(0.2), // withOpacity aquí es válido
                      child: const Icon(Icons.error, color: Colors.red),
                    ),
                  ),
                );
              }),
              if ((allTables.isNotEmpty || pageTables.isNotEmpty))
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      height: pageHeight * 0.7,
                      child: TableWidget(
                        tables: allTables.isNotEmpty ? allTables : pageTables,
                        sortColumn: sortColumn,
                        onSortTables: onSortTables,
                        maxRows: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
