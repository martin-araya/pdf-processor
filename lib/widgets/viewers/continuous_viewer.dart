import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../models/document.dart';
import '../table_widget.dart';

class ContinuousViewer extends StatelessWidget {
  final Document document;
  final List<Map<String, dynamic>> allTables;
  final List<ImageData> globalImages;
  final TextAlign textAlign;
  final Function(String)? onSortTables;

  const ContinuousViewer({
    super.key,
    required this.document,
    required this.allTables,
    required this.globalImages,
    required this.textAlign,
    this.onSortTables,
  });

  @override
  Widget build(BuildContext context) {
    final mergedText = document.continuousText ?? document.pages.map((p) => p.text).join('\n\n');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                mergedText,
                textAlign: textAlign,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          if (allTables.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TableWidget(
                tables: allTables,
                sortColumn: null,  // Simple, no sort en continuous
                onSortTables: null,
                maxRows: 10,  // Limit para perf en continuous
              ),
            ),
          if (globalImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                children: globalImages.take(5).map((img) {
                  if (img.data.isEmpty) return const SizedBox();
                  final bytes = base64Decode(img.data.split(',')[1]);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    child: Image.memory(
                      bytes,
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stk) => const Icon(Icons.error),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
