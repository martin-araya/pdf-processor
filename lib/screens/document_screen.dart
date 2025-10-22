import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/document_app_bar.dart';
import '../widgets/document_viewer.dart';
import 'document/document_controller.dart';
import 'document/document_search_controller.dart';

class DocumentScreen extends ConsumerStatefulWidget {
  final String documentId;

  const DocumentScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen>
    with DocumentController, DocumentSearchController { // Corrected mixin order
  @override
  String get documentId => widget.documentId;  // Provide documentId to mixins

  @override
  void initState() {
    super.initState();
    initializeControllers();  // From DocumentSearchController
    loadDocument();           // From DocumentController
  }

  @override
  void dispose() {
    disposeControllers();     // From DocumentSearchController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isMobile = screenWidth < 600;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      drawer: buildDrawer(context, isMobile, isPortrait), // From DocumentController
      appBar: DocumentAppBar(
        title: document?.filename ?? '',
        loading: loading,
        translating: translating,
        usePdfViewer: usePdfViewer,
        continuousMode: continuousMode,
        visualizationMode: visualizationMode,
        showSearch: isSearchVisible, // Use isSearchVisible instead of showSearch function
        textAlign: textAlign,
        isMobile: isMobile,
        isPortrait: isPortrait,
        currentLang: selectedLang,
        onZoomIn: zoomIn,
        onZoomOut: zoomOut,
        onZoomReset: zoomReset,
        onCycleTextAlign: cycleTextAlign,
        onToggleViewer: toggleViewer,
        onToggleSearch: toggleSearch,
        onToggleContinuous: toggleContinuousMode,
        onToggleVisualization: toggleVisualizationMode,
        onSortTables: sortTables,
        onTranslate: translate,
        onDelete: deleteDocument,
        onLangChanged: (value) {
          if (mounted) setState(() => selectedLang = value ?? 'es');
        },
      ),
      body: OrientationBuilder(
        builder: (context, _) => DocumentViewer(
          document: document,
          pdfBytes: pdfBytes,
          loading: loading,
          usePdfViewer: usePdfViewer,
          sidebarCollapsed: sidebarCollapsed,
          continuousView: continuousMode,
          visualizationMode: visualizationMode,
          allTables: allTables,
          sortColumn: sortColumn,
          globalImages: document?.globalImages ?? [],
          searchResults: searchResults,
          searchQuery: searchQuery,
          showSearch: isSearchVisible, // Use isSearchVisible instead of showSearch function
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          orientation: orientation,
          documentId: documentId,
          textAlign: textAlign,
          transformationController: transformationController,
          onToggleSidebar: toggleSidebar,
          itemScrollController: itemScrollController,
          bodyScrollController: bodyScrollController,
          pdfController: pdfController,
          searchResult: searchResult,
          onSearchChanged: performSearch,
          onToggleSearch: toggleSearch,
          onPreviousResult: previousSearchResult,
          onNextResult: nextSearchResult,
          onPageTap: onPageTap,
          onSortTables: sortTables,
        ),
      ),
    );
  }
}
