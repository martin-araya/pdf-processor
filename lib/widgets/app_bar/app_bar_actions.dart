import 'package:flutter/material.dart';
import 'app_bar_helpers.dart';

class AppBarActionsBuilder {
  final bool isDark;
  final bool hasActionsSpace;
  final bool showSearch;
  final bool continuousMode;
  final bool visualizationMode;
  final TextAlign textAlign;
  final bool usePdfViewer;
  final bool translating;
  final String currentLang;
  final VoidCallback? onToggleSearch;
  final VoidCallback? onToggleContinuous;
  final VoidCallback? onToggleVisualization;
  final Function(String)? onSortTables;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;
  final VoidCallback onCycleTextAlign;
  final VoidCallback onToggleViewer;
  final VoidCallback onTranslate;
  final VoidCallback onDelete;
  final Function(String) onLangChanged;
  final Function(ThemeMode) onThemeSelected;

  AppBarActionsBuilder({
    required this.isDark,
    required this.hasActionsSpace,
    required this.showSearch,
    required this.continuousMode,
    required this.visualizationMode,
    required this.textAlign,
    required this.usePdfViewer,
    required this.translating,
    required this.currentLang,
    this.onToggleSearch,
    this.onToggleContinuous,
    this.onToggleVisualization,
    this.onSortTables,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onCycleTextAlign,
    required this.onToggleViewer,
    required this.onTranslate,
    required this.onDelete,
    required this.onLangChanged,
    required this.onThemeSelected,
  });

  List<Widget> buildActions(BuildContext context) {
    final actions = <Widget>[];

    // Search toggle
    if (showSearch && onToggleSearch != null) {
      actions.add(IconButton(
        icon: const Icon(Icons.search),
        onPressed: onToggleSearch,
        tooltip: 'Buscar',
      ));
    }

    // Mode actions (continuous, visualization, sort)
    actions.addAll(_buildModeActions(context));

    // Zoom actions
    actions.addAll(_buildZoomActions());

    // Text align
    actions.add(IconButton(
      icon: Icon(AppBarHelpers.getAlignIcon(textAlign)),
      onPressed: onCycleTextAlign,
      tooltip: 'Alinear texto (${textAlign.toString().split('.').last})',
    ));

    // Viewer toggle
    actions.add(IconButton(
      icon: Icon(usePdfViewer ? Icons.picture_as_pdf : Icons.text_fields),
      onPressed: onToggleViewer,
      tooltip: 'Cambiar modo visualización',
    ));

    // Theme toggle
    actions.add(_buildThemeAction());

    // Lang dropdown
    actions.add(_buildLangAction());

    // Translate
    actions.add(IconButton(
      icon: translating
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Icon(Icons.translate),
      onPressed: translating ? null : onTranslate,
      tooltip: 'Traducir',
    ));

    // Delete
    actions.add(IconButton(
      icon: const Icon(Icons.delete),
      onPressed: onDelete,
      tooltip: 'Eliminar',
    ));

    return actions;
  }

  List<Widget> _buildModeActions(BuildContext context) {
    final modeActions = <Widget>[];

    // Continuous toggle
    if (onToggleContinuous != null) {
      if (hasActionsSpace) {
        modeActions.add(IconButton(
          icon: Icon(AppBarHelpers.getContinuousIcon(continuousMode)),
          onPressed: onToggleContinuous,
          tooltip: continuousMode ? 'Modo Paged' : 'Modo Continuous',
        ));
      } else {
        modeActions.add(PopupMenuButton<String>(
          icon: Icon(AppBarHelpers.getContinuousIcon(continuousMode)),
          onSelected: (value) => onToggleContinuous!(),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'paged', child: Text('Vista por Páginas')),
            const PopupMenuItem(value: 'continuous', child: Text('Vista Continua')),
          ],
        ));
      }
    }

    // Visualization toggle
    if (onToggleVisualization != null) {
      if (hasActionsSpace) {
        modeActions.add(IconButton(
          icon: Icon(AppBarHelpers.getVisualizationIcon(visualizationMode)),
          onPressed: onToggleVisualization,
          tooltip: visualizationMode ? 'Modo Simple' : 'Modo Visualización (Procesado)',
        ));
      } else {
        modeActions.add(PopupMenuButton<String>(
          icon: Icon(AppBarHelpers.getVisualizationIcon(visualizationMode)),
          onSelected: (value) => onToggleVisualization!(),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'simple', child: Text('Vista Simple')),
            const PopupMenuItem(value: 'visualization', child: Text('Vista Procesada')),
          ],
        ));
      }
    }

    // Sort tables
    if (onSortTables != null) {
      if (hasActionsSpace) {
        modeActions.add(IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () => AppBarHelpers.showSortMenu(context, onSortTables!),
          tooltip: 'Ordenar Tablas',
        ));
      } else {
        modeActions.add(PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          onSelected: onSortTables,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'Throughput', child: Text('Ordenar por Throughput')),
            const PopupMenuItem(value: 'Latency', child: Text('Ordenar por Latencia')),
            const PopupMenuItem(value: 'Accuracy', child: Text('Ordenar por Precisión')),
          ],
        ));
      }
    }

    return modeActions;
  }

  List<Widget> _buildZoomActions() {
    if (!hasActionsSpace) return [];
    return [
      IconButton(
        icon: const Icon(Icons.zoom_out_map),
        onPressed: onZoomOut,
        tooltip: 'Zoom Out',
      ),
      IconButton(
        icon: const Icon(Icons.zoom_in),
        onPressed: onZoomIn,
        tooltip: 'Zoom In',
      ),
      IconButton(
        icon: const Icon(Icons.zoom_out),
        onPressed: onZoomReset,
        tooltip: 'Reset Zoom',
      ),
    ];
  }

  Widget _buildThemeAction() {
    return PopupMenuButton<ThemeMode>(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onSelected: onThemeSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(value: ThemeMode.light, child: Text('Claro')),
        const PopupMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
        const PopupMenuItem(value: ThemeMode.system, child: Text('Sistema')),
      ],
    );
  }

  Widget _buildLangAction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: DropdownButton<String>(
        value: currentLang,
        underline: const SizedBox(),
        isDense: true,
        items: const [
          DropdownMenuItem(value: 'es', child: Text('Español')),
          DropdownMenuItem(value: 'en', child: Text('English')),
          DropdownMenuItem(value: 'fr', child: Text('Français')),
          DropdownMenuItem(value: 'de', child: Text('Deutsch')),
          DropdownMenuItem(value: 'it', child: Text('Italiano')),
          DropdownMenuItem(value: 'pt', child: Text('Português')),
        ],
        onChanged: (value) => onLangChanged(value ?? 'es'),
      ),
    );
  }
}
