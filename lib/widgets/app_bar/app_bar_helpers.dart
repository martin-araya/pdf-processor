import 'package:flutter/material.dart';

class AppBarHelpers {
  static IconData getAlignIcon(TextAlign align) {
    return switch (align) {
      TextAlign.start => Icons.format_align_left,
      TextAlign.center => Icons.format_align_center,
      TextAlign.end => Icons.format_align_right,
      _ => Icons.format_align_left,
    };
  }

  static IconData getContinuousIcon(bool isContinuous) {
    return isContinuous ? Icons.layers : Icons.view_stream;
  }

  static IconData getVisualizationIcon(bool isVisualization) {
    return isVisualization ? Icons.view_quilt : Icons.dashboard;
  }

  static void showSortMenu(BuildContext context, Function(String) onSortSelected) {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        const PopupMenuItem(value: 'Throughput', child: Text('Ordenar por Throughput')),
        const PopupMenuItem(value: 'Latency', child: Text('Ordenar por Latencia')),
        const PopupMenuItem(value: 'Accuracy', child: Text('Ordenar por Precisión')),
      ],
    ).then((value) {
      if (value != null) onSortSelected(value);
    });
  }
}
