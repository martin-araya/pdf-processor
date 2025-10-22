import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/pdf_uploader.dart';  // PDFUploader con onSuccess/onError
import '../services/document_service.dart';  // listDocuments, uploadPdf
import '../../models/document.dart';  // Document.fromJson
import '../core/network/dio_client.dart' show dioClientProvider;
import '../services/api_base.dart' as document_service show AuthException;
import 'document_screen.dart';  // Para nav
import 'package:intl/intl.dart';  // Para format date

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Document> _documents = [];
  bool _loading = false;  // Inicial false (carga on refresh)
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();  // Carga inicial
  }

  Future<void> _loadDocuments() async {
    if (!mounted || _loading) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioClientProvider);  // Usa DioClient con auth
      final response = await dio.get('/documents');  // Real fetch con Dio
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        final docs = data.map((json) => Document.fromJson(json as Map<String, dynamic>)).toList();
        if (mounted) {
          setState(() {
            _documents = docs;
            _loading = false;
          });
          debugPrint('✅ Documentos cargados: ${_documents.length}');
        }
      } else {
        throw Exception('Error ${response.statusCode}');
      }
    } on document_service.AuthException catch (e) {  // Asume thrown en DioError 401
      debugPrint('Auth error en load docs: $e');
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Sesión expirada')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading documents: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando documentos: $e')),
        );
      }
    }
  }

  Future<void> _refreshDocuments() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _loadDocuments();
    setState(() => _refreshing = false);
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PDFUploader(
        onSuccess: (docId) {
          Navigator.pop(context);  // Cierra sheet
          _loadDocuments();  // Refresh lista
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento subido exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (errorMsg) {
          Navigator.pop(context);  // Cierra si error (e.g., 401)
          ref.read(authProvider.notifier).logout();  // Auto-logout si 401
        },
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión? Perderás acceso a tus documentos hasta que inicies sesión nuevamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(authProvider.notifier).logout();  // Limpia token/state
        debugPrint('🔓 Sesión cerrada exitosamente');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushReplacementNamed(context, '/auth');  // Redirige a login
      } catch (e) {
        debugPrint('Error en logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cerrar sesión: $e')),
          );
        }
      }
    }
  }

  void _viewDocument(String docId) {
    Navigator.pushNamed(context, '/document', arguments: docId);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider).themeMode;  // Integra theme

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,  // Ahora con confirmación
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDocuments,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _documents.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay documentos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Sube tu primer PDF para empezar',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload),
                label: const Text('Subir PDF'),
              ),
              const SizedBox(height: 16),
              // Opcional: Volver a welcome
              // OutlinedButton(
              //   onPressed: () => Navigator.pushReplacementNamed(context, '/welcome'),
              //   child: const Text('Volver a Bienvenida'),
              // ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _documents.length,
          itemBuilder: (context, index) {
            final doc = _documents[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _viewDocument(doc.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icono PDF
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Detalles
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title ?? 'Documento sin título',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${doc.totalPages ?? 0} página${(doc.totalPages ?? 0) > 1 ? 's' : ''}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              'Creado: ${DateFormat('dd/MM/yyyy').format(doc.createdAt ?? DateTime.now())}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                            if (doc.status != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: doc.status == 'processed'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doc.status ?? '',
                                  style: TextStyle(
                                    color: doc.status == 'processed' ? Colors.green : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Arrow
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadDialog,
        tooltip: 'Subir PDF',
        child: const Icon(Icons.upload),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
