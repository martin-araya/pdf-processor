import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart'; // FIX: Importa tipos de Syncfusion
import '../models/document.dart';
import '../widgets/sidebar_document.dart';
import 'viewers/pdf_viewer_widget.dart';
import 'viewers/paged_viewer.dart';
import 'viewers/continuous_viewer.dart';
import 'viewers/visualization_viewer.dart';
import 'table_widget.dart';

class DocumentViewer extends StatelessWidget {
  final Document? document;
  final Uint8List? pdfBytes;
  final bool loading;
  final bool usePdfViewer;
  final bool sidebarCollapsed;
  final bool continuousView;
  final bool visualizationMode;
  final List<Map<String, dynamic>> allTables;
  final String? sortColumn;
  final List<ImageData> globalImages;
  final List<int> searchResults;
  final String searchQuery;
  final bool showSearch;
  final double screenWidth;
  final double screenHeight;
  final Orientation orientation;
  final String documentId;
  final TextAlign textAlign;
  final TransformationController transformationController;
  final VoidCallback onToggleSidebar;
  final ItemScrollController itemScrollController;
  final ItemScrollController bodyScrollController;
  final PdfViewerController pdfController;       // Ahora definidos por el import
  final PdfTextSearchResult searchResult;        // Ahora definidos por el import
  final Function(String) onSearchChanged;
  final VoidCallback onToggleSearch;
  final VoidCallback onPreviousResult;
  final VoidCallback onNextResult;
  final Function(int) onPageTap;
  final Function(String)? onSortTables;

  const DocumentViewer({
    super.key,
    required this.document,
    required this.pdfBytes,
    required this.loading,
    required this.usePdfViewer,
    required this.sidebarCollapsed,
    required this.continuousView,
    required this.visualizationMode,
    required this.allTables,
    this.sortColumn,
    required this.globalImages,
    required this.searchResults,
    required this.searchQuery,
    required this.showSearch,
    required this.screenWidth,
    required this.screenHeight,
    required this.orientation,
    required this.documentId,
    required this.textAlign,
    required this.transformationController,
    required this.onToggleSidebar,
    required this.itemScrollController,
    required this.bodyScrollController,
    required this.pdfController,
    required this.searchResult,
    required this.onSearchChanged,
    required this.onToggleSearch,
    required this.onPreviousResult,
    required this.onNextResult,
    required this.onPageTap,
    this.onSortTables,
  });

  Widget _buildSkeleton() {
    final estimatedPages = document?.totalPages ?? 10;
    return ScrollablePositionedList.builder(
      itemScrollController: bodyScrollController,
      itemCount: estimatedPages,
      itemBuilder: (context, index) => Container(
        margin: EdgeInsets.zero,
        width: double.infinity,
        height: 792 * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSidebar() {
    if (document == null) return const SizedBox();
    final isDesktop = screenWidth > 1200;
    final isMobile = screenWidth < 600;
    final showSidebar = (isDesktop || (orientation == Orientation.landscape && !isMobile)) && !loading;
    if (!showSidebar) return const SizedBox();

    return SidebarDocument(
      document: document!,
      searchQuery: searchQuery,
      searchResults: searchResults,
      showSearch: showSearch,
      itemScrollController: itemScrollController,
      usePdfViewer: usePdfViewer,
      hasResults: searchResults.isNotEmpty,
      isCollapsed: sidebarCollapsed,
      onToggleCollapsed: onToggleSidebar,
      onSearchChanged: onSearchChanged,
      onToggleSearch: onToggleSearch,
      onPreviousResult: onPreviousResult,
      onNextResult: onNextResult,
      onPageTap: onPageTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return _buildSkeleton();
    if (document == null) return const Center(child: Text('Error al cargar documento'));

    final isDesktop = screenWidth > 1200;
    final isMobile = screenWidth < 600;
    final showSidebar = (isDesktop || (orientation == Orientation.landscape && !isMobile));
    final bodyFlex = showSidebar ? (sidebarCollapsed ? 6 : 5) : 1;
    final contentMaxWidth = screenWidth * (showSidebar && !sidebarCollapsed ? 0.85 : 0.98);

    final sidebar = _buildSidebar();

    Widget body;
    if (usePdfViewer && pdfBytes != null) {
      body = PdfViewerWidget(
        pdfBytes: pdfBytes!,
        pdfController: pdfController,
        searchResult: searchResult,
        globalImages: globalImages,
        visualizationMode: visualizationMode,
        screenHeight: screenHeight,
      );
    } else if (visualizationMode) {
      body = VisualizationViewer(
        document: document!,
        allTables: allTables,
        globalImages: document!.globalImages ?? [],
        sortColumn: sortColumn,
        searchQuery: searchQuery,
        searchResults: searchResults,
        bodyScrollController: bodyScrollController,
        textAlign: textAlign,
        onSortTables: onSortTables,
      );
    } else if (continuousView) {
      body = ContinuousViewer(
        document: document!,
        allTables: allTables,
        globalImages: globalImages,
        textAlign: textAlign,
        onSortTables: onSortTables,
      );
    } else {
      body = PagedViewer(
        document: document!,
        documentId: documentId,
        searchQuery: searchQuery,
        textAlign: textAlign,
        bodyScrollController: bodyScrollController,
        onPageTap: onPageTap,
      );
    }

    return Row(
      children: [
        if (showSidebar) sidebar,
        Expanded(
          flex: bodyFlex,
          child: Container(
            constraints: BoxConstraints(maxWidth: contentMaxWidth, maxHeight: screenHeight * 0.95),
            child: InteractiveViewer(
              transformationController: transformationController,
              boundaryMargin: const EdgeInsets.all(10.0),
              clipBehavior: Clip.none,
              minScale: 0.5,
              maxScale: 5.0,
              child: body,
            ),
          ),
        ),
      ],
    );
  }
}
