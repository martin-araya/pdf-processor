import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/theme_provider.dart';
import 'app_bar/app_bar_actions.dart';
import 'app_bar/app_bar_helpers.dart';

class DocumentAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool loading;
  final bool translating;
  final bool usePdfViewer;
  final bool continuousMode;
  final bool visualizationMode;
  final bool showSearch;
  final TextAlign textAlign;
  final bool isMobile;
  final bool isPortrait;
  final String currentLang;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;
  final VoidCallback onCycleTextAlign;
  final VoidCallback onToggleViewer;
  final VoidCallback? onToggleSearch;
  final VoidCallback? onToggleContinuous;
  final VoidCallback? onToggleVisualization;
  final Function(String)? onSortTables;
  final VoidCallback onTranslate;
  final VoidCallback onDelete;
  final Function(String) onLangChanged;
  final Widget? drawer;

  const DocumentAppBar({
    super.key,
    required this.title,
    required this.loading,
    required this.translating,
    required this.usePdfViewer,
    required this.continuousMode,
    required this.visualizationMode,
    required this.showSearch,
    required this.textAlign,
    required this.isMobile,
    required this.isPortrait,
    this.currentLang = 'es',
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onCycleTextAlign,
    required this.onToggleViewer,
    this.onToggleSearch,
    this.onToggleContinuous,
    this.onToggleVisualization,
    this.onSortTables,
    required this.onTranslate,
    required this.onDelete,
    required this.onLangChanged,
    this.drawer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final hasActionsSpace = !isMobile || !isPortrait;

    return AppBar(
      title: Text(loading ? 'Cargando...' : title),
      leading: isMobile && isPortrait && drawer != null
          ? IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openDrawer(),
        tooltip: 'Menú',
      )
          : null,
      actions: AppBarActionsBuilder(
        isDark: isDark,
        hasActionsSpace: hasActionsSpace,
        showSearch: showSearch,
        continuousMode: continuousMode,
        visualizationMode: visualizationMode,
        textAlign: textAlign,
        usePdfViewer: usePdfViewer,
        translating: translating,
        currentLang: currentLang,
        onToggleSearch: onToggleSearch,
        onToggleContinuous: onToggleContinuous,
        onToggleVisualization: onToggleVisualization,
        onSortTables: onSortTables,
        onZoomIn: onZoomIn,
        onZoomOut: onZoomOut,
        onZoomReset: onZoomReset,
        onCycleTextAlign: onCycleTextAlign,
        onToggleViewer: onToggleViewer,
        onTranslate: onTranslate,
        onDelete: onDelete,
        onLangChanged: onLangChanged,
        onThemeSelected: (mode) {
          if (mode == ThemeMode.dark) {
            ref.read(themeProvider.notifier).toggleTheme(true);
          } else if (mode == ThemeMode.light) {
            ref.read(themeProvider.notifier).toggleTheme(false);
          } else {
            ref.read(themeProvider.notifier).setSystem();
          }
        },
      ).buildActions(context),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
