import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;  // Para debugPrint
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/document.dart';
import '../../services/document_service.dart' as document_service;  // Para getDocument, getPdf, etc.
import '../../services/auth_service.dart' as auth_service;  // No directo, pero para AuthException via api_base
import '../../core/providers/auth_provider.dart';
import '../../widgets/sidebar_document.dart';
import 'document_search_controller.dart';
import '../../services/api_base.dart' show AuthException;  // AuthException

mixin DocumentController<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  // Abstract properties to be implemented by the state or another mixin
  String get documentId;
  String get searchQuery;
  List<int> get searchResults;
  bool get isSearchVisible;
  ItemScrollController get itemScrollController;
  void performSearch(String query);
  void toggleSearch();
  void previousSearchResult();
  void nextSearchResult();
  void onPageTap(int index);

  // State fields
  Document? document;
  Uint8List? pdfBytes;
  bool loading = true;
  bool translating = false;
  bool usePdfViewer = true;
  bool sidebarCollapsed = false;
  bool continuousMode = false;
  bool visualizationMode = false;
  List<Map<String, dynamic>> allTables = [];
  String? sortColumn = 'default';
  String selectedLang = 'es';
  TextAlign textAlign = TextAlign.start;

  Future<void> loadDocument() async {
    try {
      final mode = visualizationMode ? 'visualization' : (continuousMode ? 'continuous' : 'paged');
      final doc = await document_service.DocumentService.getDocument(
        documentId,
        includeImages: true,
        mode: mode,
      );
      Uint8List? bytes;
      if (usePdfViewer) {
        try {
          bytes = await document_service.DocumentService.getPdf(documentId);
        } catch (e) {
          debugPrint('PDF no disponible: $e');
          if (mounted) setState(() => usePdfViewer = false);
        }
      }
      if (mounted && doc != null) {
        List<Map<String, dynamic>> tables = doc.allTables ?? [];
        if (tables.isEmpty && doc.pages != null) {
          for (var page in doc.pages ?? []) {
            tables.addAll(page.tables ?? <Map<String, dynamic>>[]);
          }
        }
        if (mounted) {
          setState(() {
            document = doc;
            allTables = tables;
            pdfBytes = bytes;
            loading = false;
          });
        }
        debugPrint('✅ Documento cargado: ${doc.totalPages} páginas, mode: $mode');
      } else if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento no encontrado')));
      }
    } on AuthException catch (e) {
      debugPrint('Auth error en load: $e');
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error de autenticación')));
      }
    } catch (e) {
      debugPrint('❌ Error loadDocument: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando: $e')));
        setState(() => loading = false);
      }
    }
  }

  Future<void> translate() async {
    if (mounted) setState(() => translating = true);
    try {
      final translated = await document_service.DocumentService.translateDocument(documentId, selectedLang);
      if (mounted) {
        setState(() {
          document = translated;
          translating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Traducido a $selectedLang')));
      }
    } on AuthException catch (e) {
      debugPrint('Auth error en translate: $e');
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
        setState(() => translating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error de autenticación')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => translating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error traduciendo: $e')));
      }
    }
  }

  Future<void> deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Documento'),
        content: const Text('¿Seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await document_service.DocumentService.deleteDocument(documentId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado')));
        }
      } on AuthException catch (e) {
        debugPrint('Auth error en delete: $e');
        final authNotifier = ref.read(authProvider.notifier);
        await authNotifier.logout();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/auth');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error de autenticación')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void toggleContinuousMode() async {
    if (mounted) {
      setState(() {
        continuousMode = !continuousMode;
        visualizationMode = false;
        loading = true;
      });
    }
    try {
      await loadDocument();
    } catch (e) {
      debugPrint('Error en toggleContinuous: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  void toggleVisualizationMode() async {
    if (mounted) {
      setState(() {
        visualizationMode = !visualizationMode;
        continuousMode = false;
        loading = true;
      });
    }
    try {
      await loadDocument();
    } catch (e) {
      debugPrint('Error en toggleVisualization: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  void sortTables(String column) {
    if (allTables.isEmpty || !mounted) return;
    setState(() {
      sortColumn = (sortColumn == column) ? '${column}_desc' : column;
      allTables.sort((a, b) {
        final valA = a['rows']?[0]?[column] ?? '';
        final valB = b['rows']?[0]?[column] ?? '';
        final compare = (valA is num && valB is num)
            ? valA.compareTo(valB)
            : valA.toString().toLowerCase().compareTo(valB.toString().toLowerCase());
        return (sortColumn!.endsWith('_desc')) ? -compare : compare;
      });
    });
    debugPrint('Tablas ordenadas por $sortColumn');
  }

  void toggleSidebar() {
    if (mounted) {
      setState(() => sidebarCollapsed = !sidebarCollapsed);
    }
  }

  void cycleTextAlign() {
    if (mounted) {
      setState(() {
        switch (textAlign) {
          case TextAlign.start:
            textAlign = TextAlign.center;
            break;
          case TextAlign.center:
            textAlign = TextAlign.end;
            break;
          case TextAlign.end:
            textAlign = TextAlign.start;
            break;
          default:
            textAlign = TextAlign.start;
        }
      });
    }
    if (usePdfViewer) debugPrint('Alineación: $textAlign (PDF fijo)');
  }

  void toggleViewer() async {
    if (mounted) setState(() => usePdfViewer = !usePdfViewer);
    if (usePdfViewer && pdfBytes == null && mounted) {
      try {
        await loadDocument();
      } catch (e) {
        debugPrint('Error en toggleViewer: $e');
      }
    }
  }

  void zoomIn() {
    if (mounted) setState(() {});
  }

  void zoomOut() {
    if (mounted) setState(() {});
  }

  void zoomReset() {
    if (mounted) setState(() {});
  }

  Widget buildDrawer(BuildContext context, bool isMobile, bool isPortrait) {
    if (!mounted || loading || document == null || !isMobile || !isPortrait) {
      return loading
          ? const Drawer(child: Center(child: CircularProgressIndicator()))
          : const SizedBox();
    }
    return SidebarDocument(
      document: document!,
      searchQuery: searchQuery,
      searchResults: searchResults,
      showSearch: isSearchVisible,
      itemScrollController: itemScrollController,
      usePdfViewer: usePdfViewer,
      hasResults: searchResults.isNotEmpty,
      isCollapsed: false,
      onToggleCollapsed: () {},
      onSearchChanged: performSearch,
      onToggleSearch: toggleSearch,
      onPreviousResult: previousSearchResult,
      onNextResult: nextSearchResult,
      onPageTap: onPageTap,
    );
  }
}
