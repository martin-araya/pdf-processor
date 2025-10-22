import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/api_service.dart';

// FIX: Remueve vector_math (innecesario; Matrix4 de material.dart)
// FIX: Imports limpios, sin duplicados

// FIX: on State<T> (no ref needed aquí; si auth/logout, cambia a ConsumerState<T>)
mixin DocumentSearchController<T extends StatefulWidget> on State<T> {
  // Controllers y state para search (accesibles en screen)
  late ItemScrollController itemScrollController;
  late ItemScrollController bodyScrollController;
  late TransformationController transformationController;
  late PdfViewerController pdfController;
  late PdfTextSearchResult searchResult;
  String searchQuery = '';
  bool isSearchVisible = false;
  List<int> searchResults = [];
  int currentSearchIndex = 0;

  // FIX: Remueve @override (no hereda de State; método custom)
  void initializeControllers() {
    itemScrollController = ItemScrollController();
    bodyScrollController = ItemScrollController();
    transformationController = TransformationController();
    pdfController = PdfViewerController();
    searchResult = PdfTextSearchResult();
    searchResult.addListener(_updateSearchUI);
    pdfController.addListener(_updateSearchUI);
    debugPrint('✅ Controllers inicializados para search');
  }

  // FIX: Remueve @override (método custom)
  void disposeControllers() {
    searchResult.removeListener(_updateSearchUI);
    pdfController.removeListener(_updateSearchUI);
    searchResult.dispose();
    // Opcional: transformationController.dispose(); si needed
    debugPrint('🧹 Controllers disposed para search');
  }

  void _updateSearchUI() {
    // FIX: Null check para shared fields de DocumentController
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    if (!mounted || !usePdfLocal) return;
    if (searchResult.hasResult) {
      final currentPage = pdfController.pageNumber - 1;
      if (mounted) {
        setState(() {
          searchResults = [currentPage];
          isSearchVisible = true;
        });
      }
      pdfController.jumpToPage(currentPage + 1);
    } else if (mounted) {
      setState(() => searchResults = []);
    }
  }

  void performSearch(String query) {
    if (mounted) {
      setState(() {
        searchQuery = query;
        currentSearchIndex = 0;
        isSearchVisible = true;
      });
    }
    if (query.isEmpty) {
      searchResult.clear();
      if (mounted) setState(() => searchResults = []);
      return;
    }
    try {
      // FIX: Null checks para shared fields
      final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
      final pdfBytesLocal = (this as dynamic).pdfBytes;
      if (usePdfLocal && pdfBytesLocal != null) {
        searchResult = pdfController.searchText(query);
        if (!kIsWeb) {
          if (searchResult.isSearchCompleted) _updateSearchUI();
        } else {
          _updateSearchUI();
        }
      } else {
        final results = <int>[];
        final docLocal = (this as dynamic).document;
        final pagesLength = docLocal?.pages.length ?? 0;
        for (int i = 0; i < pagesLength; i++) {
          final pageText = docLocal?.pages[i].text ?? '';
          if (pageText.toLowerCase().contains(query.toLowerCase())) results.add(i);
        }
        if (mounted) setState(() => searchResults = results);
        if (results.isNotEmpty && bodyScrollController.isAttached) {
          bodyScrollController.scrollTo(
            index: results.first,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
      debugPrint('🔍 Búsqueda: "$query" → ${searchResults.length} resultados');
    } catch (e) {
      debugPrint('Error en performSearch: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en búsqueda: $e')));
    }
  }

  void nextSearchResult() {
    // FIX: Null check
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    if (usePdfLocal && searchResult.hasResult) {
      searchResult.nextInstance();
    } else if (searchResults.isNotEmpty) {
      final nextIndex = (currentSearchIndex + 1) % searchResults.length;
      if (mounted) setState(() => currentSearchIndex = nextIndex);
      if (bodyScrollController.isAttached) {
        bodyScrollController.scrollTo(
          index: searchResults[nextIndex],
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void previousSearchResult() {
    // FIX: Null check
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    if (usePdfLocal && searchResult.hasResult) {
      searchResult.previousInstance();
    } else if (searchResults.isNotEmpty) {
      var prevIndex = (currentSearchIndex - 1) % searchResults.length;
      if (prevIndex < 0) prevIndex += searchResults.length;
      if (mounted) setState(() => currentSearchIndex = prevIndex);
      if (bodyScrollController.isAttached) {
        bodyScrollController.scrollTo(
          index: searchResults[prevIndex],
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void toggleSearch() {
    if (mounted) setState(() => isSearchVisible = !isSearchVisible);
  }

  void onPageTap(int index) {
    // FIX: Null checks para shared fields
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    final pdfBytesLocal = (this as dynamic).pdfBytes;
    if (usePdfLocal && pdfBytesLocal != null) {
      pdfController.jumpToPage(index + 1);
    } else if (bodyScrollController.isAttached) {
      bodyScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // Zoom methods (usa controllers locales)
  // FIX: Agrega mounted checks y null checks para shared
  void zoomIn() {
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    final pdfBytesLocal = (this as dynamic).pdfBytes;
    if (usePdfLocal && pdfBytesLocal != null) {
      final newZoom = (pdfController.zoomLevel + 0.5).clamp(0.1, 4.0);
      pdfController.zoomLevel = newZoom;
    } else {
      final currentScale = transformationController.value.getMaxScaleOnAxis();
      final newScale = (currentScale + 0.5).clamp(0.5, 5.0);
      transformationController.value = Matrix4.identity()..scale(newScale);
    }
    if (mounted) setState(() {});
    debugPrint('🔍 Zoom in: ${usePdfLocal ? pdfController.zoomLevel : transformationController.value.getMaxScaleOnAxis()}');
  }

  void zoomOut() {
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    final pdfBytesLocal = (this as dynamic).pdfBytes;
    if (usePdfLocal && pdfBytesLocal != null) {
      final newZoom = (pdfController.zoomLevel - 0.5).clamp(0.1, 4.0);
      pdfController.zoomLevel = newZoom;
    } else {
      final currentScale = transformationController.value.getMaxScaleOnAxis();
      final newScale = (currentScale - 0.5).clamp(0.5, 5.0);
      transformationController.value = Matrix4.identity()..scale(newScale);
    }
    if (mounted) setState(() {});
    debugPrint('🔍 Zoom out: ${usePdfLocal ? pdfController.zoomLevel : transformationController.value.getMaxScaleOnAxis()}');
  }

  void zoomReset() {
    final usePdfLocal = (this as dynamic).usePdfViewer ?? false;
    final pdfBytesLocal = (this as dynamic).pdfBytes;
    if (usePdfLocal && pdfBytesLocal != null) {
      pdfController.zoomLevel = 0.0;
    } else {
      transformationController.value = Matrix4.identity();
    }
    if (mounted) setState(() {});
    debugPrint('🔍 Zoom reset');
  }
}
