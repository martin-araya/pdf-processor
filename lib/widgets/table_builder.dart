import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TableBuilder extends StatelessWidget {
  final String tableText;
  final TextAlign textAlign;
  final int index;

  const TableBuilder({
    super.key,
    required this.tableText,
    required this.textAlign,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    if (!_isTableDetected(tableText)) return const SizedBox.shrink();

    final lines = tableText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final tableData = <List<String>>[];
    for (final line in lines) {
      final words = line.trim().split(RegExp(r'\s{2,}')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2) tableData.add(words);
    }

    final numCols = tableData[0].length;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 700),
          child: DataTable(
            key: ValueKey('table_$index'),
            columns: List.generate(numCols, (i) => DataColumn(
              label: Text(
                tableData[0][i],
                style: GoogleFonts.lora(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: textAlign,
              ),
            )),
            rows: tableData.skip(1).map((row) => DataRow(
              cells: List.generate(numCols, (i) {
                final cellText = row.length > i ? row[i] : '';
                return DataCell(
                  Text(
                    cellText,
                    style: GoogleFonts.lora(fontSize: 11),
                    textAlign: textAlign,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                );
              }),
            )).toList(),
            headingRowColor: WidgetStateProperty.all(theme.colorScheme.primary.withOpacity(0.1)),
            border: TableBorder.all(color: Colors.grey[300]!, width: 1),
            dataRowHeight: 35,
          ),
        ),
      ),
    );
  }

  // Detecta tabla (duplicado para independencia; remueve si merges)
  bool _isTableDetected(String text) {
    if (text.isEmpty) return false;
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
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
}
