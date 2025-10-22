import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'table_builder.dart';

class TextRenderer extends StatelessWidget {
  final String text;
  final String searchQuery;
  final TextAlign textAlign;
  final double fontSize;
  final int index;

  const TextRenderer({
    super.key,
    required this.text,
    required this.searchQuery,
    required this.textAlign,
    required this.fontSize,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Si todo el bloque es una tabla, muestra la tabla completa
    if (_isTableDetected(text)) {
      return TableBuilder(
        tableText: text,
        textAlign: textAlign,
        index: index,
      );
    }

    // Caso general: texto con posibles tablas inline por párrafos
    return Container(
      key: ValueKey('text_$index'),
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      child: RichText(
        text: TextSpan(children: _buildTextSpansForParagraphs(context)),
        textAlign: textAlign,
      ),
    );
  }

  // Detecta si un bloque parece tabla
  bool _isTableDetected(String value) {
    if (value.isEmpty) return false;
    final lines = value.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.length < 2) return false;

    final tableData = <List<String>>[];
    bool isTable = false;
    for (final line in lines) {
      final words = line.trim().split(RegExp(r'\s{2,}')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2) {
        tableData.add(words);
        isTable = true;
      } else if (line.contains(RegExp(r'[-=]{2,}'))) {
        isTable = true;
      }
    }
    return isTable && tableData.length >= 2 && tableData[0].length >= 2;
  }

  // Spans con highlight para un string (usa Theme desde context)
  List<InlineSpan> _buildTextSpans(BuildContext context, String value) {
    final style = GoogleFonts.lora(
      fontSize: fontSize,
      height: 1.3,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final highlightedStyle = style.copyWith(
      backgroundColor: Colors.yellow.withOpacity(0.8),
    );

    final spans = <InlineSpan>[];
    int lastIndex = 0;
    if (searchQuery.isEmpty) {
      spans.add(TextSpan(text: value, style: style));
      return spans;
    }

    final regex = RegExp(RegExp.escape(searchQuery), caseSensitive: false);
    for (final match in regex.allMatches(value)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: value.substring(lastIndex, match.start), style: style));
      }
      spans.add(TextSpan(text: value.substring(match.start, match.end), style: highlightedStyle));
      lastIndex = match.end;
    }
    if (lastIndex < value.length) {
      spans.add(TextSpan(text: value.substring(lastIndex), style: style));
    }
    return spans;
  }

  // Construye spans por párrafos, incrustando tablas como WidgetSpan cuando corresponda
  List<InlineSpan> _buildTextSpansForParagraphs(BuildContext context) {
    final paragraphs = text.split('\n\n');
    final allSpans = <InlineSpan>[];

    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) {
        allSpans.add(const TextSpan(text: '\n\n'));
        continue;
      }

      if (_isTableDetected(trimmed)) {
        allSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                key: ValueKey('inline_table_$index'),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TableBuilder(
                  tableText: trimmed,
                  textAlign: textAlign,
                  index: index,
                ),
              ),
            ),
          ),
        );
        allSpans.add(const TextSpan(text: '\n\n'));
      } else {
        allSpans.addAll(_buildTextSpans(context, trimmed));
        allSpans.add(const TextSpan(text: '\n\n'));
      }
    }
    return allSpans;
  }
}
