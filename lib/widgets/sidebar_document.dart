import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/document.dart';

class SidebarDocument extends StatelessWidget {
  final Document document;
  final String searchQuery;
  final List<int> searchResults;
  final bool showSearch;
  final ItemScrollController itemScrollController;
  final bool usePdfViewer;
  final bool hasResults;  // Prop para search results (de parent)
  final bool isCollapsed;  // Nuevo: Estado colapsado
  final Function() onToggleCollapsed;  // Callback para toggle
  final Function(String) onSearchChanged;
  final Function() onToggleSearch;
  final VoidCallback? onPreviousResult;
  final VoidCallback? onNextResult;
  final Function(int)? onPageTap;  // Callback para taps en páginas

  const SidebarDocument({
    super.key,
    required this.document,
    required this.searchQuery,
    required this.searchResults,
    required this.showSearch,
    required this.itemScrollController,
    required this.usePdfViewer,
    required this.hasResults,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.onSearchChanged,
    required this.onToggleSearch,
    this.onPreviousResult,
    this.onNextResult,
    this.onPageTap,
  });

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: showSearch ? 60 : 0,
      child: showSearch ? Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SearchBar(
          hintText: 'Buscar en documento...',
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: onSearchChanged,
          leading: const Icon(Icons.search),
          trailing: [
            if (hasResults) ...[
              IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: onPreviousResult, tooltip: 'Anterior'),
              IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: onNextResult, tooltip: 'Siguiente'),
            ],
            if (searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear), onPressed: () => onSearchChanged(''), tooltip: 'Limpiar'),
          ],
        ),
      ) : const SizedBox(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expandedWidth = 280.0;
    final collapsedWidth = 60.0;  // Ancho mínimo para botón
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? collapsedWidth : expandedWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(2, 0))],
      ),
      child: Column(
        children: [
          // Header con botón retractar
          Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                if (isCollapsed) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 24),
                    onPressed: onToggleCollapsed,
                    tooltip: 'Expandir sidebar',
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(document.filename, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${document.totalPages} páginas', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 24),
                    onPressed: onToggleCollapsed,
                    tooltip: 'Retraer sidebar',
                  ),
                ],
              ],
            ),
          ),
          // Search section (oculta si collapsed)
          if (!isCollapsed)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggleSearch,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: showSearch ? theme.colorScheme.primary.withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Buscar', style: theme.textTheme.bodyMedium)),
                        Icon(showSearch ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
                      ],
                    ),
                    if (showSearch) ...[
                      const SizedBox(height: 8),
                      _buildSearchBar(context),
                    ],
                  ],
                ),
              ),
            ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: isCollapsed
                ? Center(child: IconButton(icon: const Icon(Icons.list, size: 24), onPressed: onToggleCollapsed))
                : ScrollablePositionedList.builder(
              physics: const ClampingScrollPhysics(),
              itemCount: document.pages.length,
              itemScrollController: itemScrollController,
              itemBuilder: (context, index) {
                final isSelected = searchResults.contains(index);
                return InkWell(
                  onTap: () => onPageTap?.call(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        child: Text('${index + 1}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      title: Text('Página ${index + 1}', style: theme.textTheme.bodyMedium),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.05),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!isCollapsed && usePdfViewer && searchQuery.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
              ),
              child: Text('Instancias: ${searchResults.length}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ],
      ),
    );
  }
}
