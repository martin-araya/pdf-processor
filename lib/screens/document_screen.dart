import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';  // Para scrollTo en sidebar
import '../models/document.dart';
import '../services/api_service.dart';
import '../widgets/page_card.dart';  // Usa versión simplificada abajo

class DocumentScreen extends StatefulWidget {
  final String documentId;

  const DocumentScreen({super.key, required this.documentId});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  final ApiService _api = ApiService();
  Document? _document;
  bool _loading = true;
  bool _translating = false;
  String _selectedLang = 'es';
  final ScrollController _scrollController = ScrollController();
  final ItemScrollController _itemScrollController = ItemScrollController();  // Para sidebar nav

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await _api.getDocument(widget.documentId, includeImages: true);
      if (mounted) {
        setState(() {
          _document = doc;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _translate() async {
    setState(() => _translating = true);
    try {
      final translated = await _api.translateDocument(widget.documentId, _selectedLang);
      if (mounted) {
        setState(() {
          _document = translated;
          _translating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Traducido a $_selectedLang')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _translating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error traduciendo: $e')));
      }
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Documento'),
        content: const Text('¿Seguro que quieres eliminar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _api.deleteDocument(widget.documentId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento eliminado')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error eliminando: $e')));
        }
      }
    }
  }

  // Skeleton: Simula páginas continuas
  Widget _buildSkeleton(int estimatedPages) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: List.generate(estimatedPages, (index) => Container(
          margin: const EdgeInsets.only(bottom: 2),  // Mínimo gap para "hojas"
          width: double.infinity,
          height: 792 * 0.8,  // Altura A4 escalada
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: const SizedBox(),
          ),
        )),
      ),
    );
  }

  // Sidebar: Lista páginas para nav
  Widget _buildSidebar() {
    if (_loading || _document == null) return const Drawer(child: Center(child: CircularProgressIndicator()));
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Text('${_document!.filename} (${_document!.totalPages} páginas)'),
          ),
          Expanded(
            child: ScrollablePositionedList.builder(
              itemCount: _document!.pages.length,
              itemScrollController: _itemScrollController,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('Página ${index + 1}'),
                onTap: () => _itemScrollController.scrollTo(
                  index: index,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Layout principal: Continuo en scroll
  Widget _buildBody(double screenWidth) {
    if (_loading) return _buildSkeleton(_document?.totalPages ?? 10);
    if (_document == null) return const Center(child: Text('Error al cargar documento'));

    final isDesktop = screenWidth > 1200;
    return Row(  // Desktop: Sidebar + content
      children: [
        if (isDesktop) Expanded(child: _buildSidebar()),
        Expanded(
          flex: isDesktop ? 3 : 1,  // Content toma más espacio
          child: InteractiveViewer(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: _document!.pages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final page = entry.value;
                  return Container(
                    key: ValueKey('page_$index'),  // Para scrollTo
                    margin: const EdgeInsets.only(bottom: 4),  // Mínimo para separar hojas
                    width: double.infinity,
                    child: AspectRatio(
                      aspectRatio: page.dimensions.width / page.dimensions.height,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: PageContent(  // Simplificado de PageCard
                          page: page,
                          documentId: widget.documentId,
                          index: index,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      drawer: ! (screenWidth > 1200) ? _buildSidebar() : null,  // Drawer en mobile/tablet
      appBar: AppBar(
        title: Text(_document?.filename ?? 'Cargando...'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedLang,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'es', child: Text('Español')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'it', child: Text('Italiano')),
                DropdownMenuItem(value: 'pt', child: Text('Português')),
              ],
              onChanged: (value) => setState(() => _selectedLang = value ?? 'es'),
            ),
          ),
          IconButton(
            icon: _translating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.translate),
            onPressed: _translating ? null : _translate,
            tooltip: 'Traducir',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteDocument,
            tooltip: 'Eliminar',
          ),
          if (screenWidth <= 1200) IconButton(  // Menu para sidebar en mobile
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => _buildBody(constraints.maxWidth),
      ),
    );
  }
}
