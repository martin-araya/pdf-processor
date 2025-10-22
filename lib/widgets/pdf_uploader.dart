import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;  // Agregado para consistency
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Para PlatformFile
import '../services/document_service.dart' as document_service; // DocumentService.uploadPdf

class PDFUploader extends StatefulWidget {
  final Function(String documentId) onSuccess;
  final Function(String)? onError;  // Nueva: Para manejar 401 (auto-logout en parent)

  const PDFUploader({
    super.key,
    required this.onSuccess,
    this.onError,
  });

  @override
  State<PDFUploader> createState() => _PDFUploaderState();
}

class _PDFUploaderState extends State<PDFUploader> {
  bool _uploading = false;
  double _progress = 0.0;
  String? _selectedFileName;

  Future<void> _pickAndUploadFile() async {
    try {
      // Seleccionar archivo con withData: true para cross-platform
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Obtiene bytes (web) o path (desktop)
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) _showError('Selección cancelada');
        return;
      }

      final PlatformFile platformFile = result.files.first;

      // Verificar PDF y size (10MB limit)
      if (platformFile.extension?.toLowerCase() != 'pdf') {
        if (mounted) _showError('Archivo no válido. Elige un PDF.');
        return;
      }
      if (platformFile.size > 10 * 1024 * 1024) {  // 10MB
        if (mounted) _showError('Archivo demasiado grande (>10MB).');
        return;
      }

      setState(() {
        _uploading = true;
        _progress = 0.0;
        _selectedFileName = platformFile.name;
      });

      // Subir con DocumentService (usa interceptor JWT + onSendProgress)
      final response = await document_service.DocumentService.uploadPdf(
        platformFile,
        onSendProgress: (count, total) {
          if (mounted && total > 0) {
            setState(() => _progress = count / total);  // Progreso real (count/total)
          }
        },
      );

      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 1.0;  // Completo
        });

        // Verificar y llamar callback con ID
        if (response.containsKey('id') && response['id'] != null) {
          widget.onSuccess(response['id'] as String);
          if (mounted) _showSuccess('PDF subido: ${platformFile.name} (ID: ${response['id']})');
        } else {
          final errorMsg = 'Respuesta inesperada del servidor (sin ID). Verifica logs.';
          debugPrint('Respuesta completa: $response'); // Para debug
          if (mounted) _showError(errorMsg);
        }
      }
    } on DioException catch (e) {
      debugPrint('Dio error en upload: Status ${e.response?.statusCode}, Data ${e.response?.data}');
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0.0;
        });
      }

      String message;
      switch (e.response?.statusCode) {
        case 401:
          message = 'Sesión expirada. Redirigiendo al login.';
          widget.onError?.call(message);  // Llama parent onError (e.g., auto-logout)
          break;
        case 400:
          message = 'Error 400: No se recibió el archivo. Verifica conexión o backend.';
          break;
        case 413:  // Payload too large
          message = 'Archivo demasiado grande. Máximo 10MB.';
          break;
        case 500:
          message = 'Error interno del servidor. Intenta de nuevo.';
          break;
        default:
          message = 'Error de red: ${e.message ?? 'Desconocido'}';
      }
      if (mounted && e.response?.statusCode != 401) {  // No snack si 401 (parent maneja)
        _showError(message);
      }
    } catch (e) {
      debugPrint('Error general en upload: $e');
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0.0;
        });
        _showError('Error al subir: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de carga
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(  // const agregado
                  color: Color(0xFFE3F2FD),  // blue.shade50 explícito
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _uploading ? Icons.cloud_upload : Icons.picture_as_pdf,
                  size: 40,
                  color: const Color(0xFF1976D2),  // blue.shade700 explícito
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                _uploading ? 'Subiendo PDF...' : 'Selecciona un PDF',
                style: const TextStyle(  // const
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Descripción
              Text(
                _uploading
                    ? 'Procesando ${_selectedFileName ?? "archivo"}'
                    : 'Procesaremos el PDF y extraeremos texto e imágenes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Botón o indicador de progreso
              if (_uploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 16),
                    Text(
                      'Subiendo ${_selectedFileName ?? "archivo"}...',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir PDF'),  // const
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

              // Información adicional
              if (!_uploading) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(  // const donde posible
                    color: const Color(0xFFE3F2FD),  // blue.shade50
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: const Color(0xFF1976D2), size: 20),  // blue.shade700
                      const SizedBox(width: 12),
                      const Expanded(  // const
                        child: Text(
                          'Tamaño máximo: 10MB',
                          style: TextStyle(  // const
                            fontSize: 12,
                            color: Color(0xFF0D47A1),  // blue[900]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
