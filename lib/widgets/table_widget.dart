import 'package:flutter/material.dart';

class TableWidget extends StatelessWidget {
  final List<Map<String, dynamic>> tables;
  final String? sortColumn;
  final Function(String)? onSortTables;
  final int maxRows;

  const TableWidget({
    super.key,
    required this.tables,
    this.sortColumn,
    this.onSortTables,
    this.maxRows = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (tables.isEmpty) {
      return DataTable(
        columns: const [DataColumn(label: Text('No Data'))],
        rows: const [],
      );
    }

    final columns = _buildColumns(tables);
    final rows = _buildRows(tables, sortColumn);

    return DataTable(
      columns: columns
          .map((col) => DataColumn(
        label: GestureDetector(
          onTap: () => onSortTables?.call(col.label.toString().toLowerCase()),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(child: col.label),
                if (sortColumn != null &&
                    col.label
                        .toString()
                        .toLowerCase()
                        .contains(sortColumn!.split('_')[0].toLowerCase()))
                  Icon(
                    sortColumn!.endsWith('_desc') ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ))
          .toList(),
      rows: rows.take(maxRows).toList(),
      sortColumnIndex: _getSortIndex(sortColumn),
      sortAscending: sortColumn == null || !sortColumn!.endsWith('_desc'),
      headingRowColor: WidgetStateProperty.all(Colors.grey[100]!),
      // FIX deprecations:
      dataRowMinHeight: 48.0,
      dataRowMaxHeight: 48.0,
      headingRowHeight: 56.0,
    );
  }

  List<DataColumn> _buildColumns(List<Map<String, dynamic>> tables) {
    if (tables.isEmpty) return const [DataColumn(label: Text('No Columns'))];
    final Set<String> headers = <String>{};
    for (var table in tables) {
      final rows = table['rows'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final headerRow = rows.first as List?;
        if (headerRow != null) {
          headers.addAll(headerRow.map((h) => h.toString()).cast<String>());
        }
      }
    }
    return headers.toList().take(8).map((h) {
      final headerStr = h; // no hace falta cast redundante
      final capitalized = headerStr.isEmpty ? 'Col' : headerStr[0].toUpperCase() + headerStr.substring(1);
      return DataColumn(label: Text(capitalized));
    }).toList();
  }

  List<DataRow> _buildRows(List<Map<String, dynamic>> tables, String? sortCol) {
    final allRows = <List<dynamic>>[];
    for (var table in tables) {
      final tableRows = table['rows'] as List?;
      if (tableRows != null && tableRows.length > 1) {
        for (int i = 1; i < tableRows.length; i++) {
          allRows.add(tableRows[i] as List<dynamic>);
        }
      }
    }
    final colIndex = _getColumnIndexFromName(allRows.isNotEmpty ? allRows.first.length : 0, sortCol);
    if (sortCol != null && allRows.isNotEmpty && colIndex >= 0) {
      allRows.sort((a, b) {
        final valA = a[colIndex];
        final valB = b[colIndex];
        final numA = num.tryParse(valA.toString());
        final numB = num.tryParse(valB.toString());
        final compare = (numA != null && numB != null)
            ? numA.compareTo(numB)
            : valA.toString().toLowerCase().compareTo(valB.toString().toLowerCase());
        return sortCol.endsWith('_desc') ? -compare : compare;
      });
    }
    return allRows
        .map((rowCells) => DataRow(
      cells: rowCells.map((cell) => DataCell(Text(cell.toString()))).toList(),
    ))
        .toList();
  }

  int _getColumnIndexFromName(int totalCols, String? colName) {
    if (colName == null) return -1;
    final headers = ['throughput', 'latency', 'accuracy', 'benchmark', 'model'];
    final name = colName.split('_')[0].toLowerCase();
    final idx = headers.indexOf(name);
    if (idx < 0) return -1;
    return idx.clamp(0, totalCols - 1);
  }

  int _getSortIndex(String? column) {
    return _getColumnIndexFromName(5, column);
  }
}
