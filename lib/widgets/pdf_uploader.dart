import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Para PlatformFile
import '../services/api_service.dart'; // Ajusta ruta si necesario

class PDFUploader extends StatefulWidget {
  final Function(String documentId) onSuccess;

  const PDFUploader({super.key, required this.onSuccess});

  @override
  State<PDFUploader> createState() => _PDFUploaderState();
}

class _PDFUploaderState extends State<PDFUploader> {
  final ApiService _api = ApiService();
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
        _showError('Selección cancelada');
        return;
      }

      final PlatformFile platformFile = result.files.first; // Directo: PlatformFile del picker

      // Verificar PDF
      if (platformFile.extension?.toLowerCase() != 'pdf') {
        _showError('Archivo no válido. Elige un PDF.');
        return;
      }

      setState(() {
        _uploading = true;
        _progress = 0.0;
        _selectedFileName = platformFile.name;
      });

      // Subir archivo con PlatformFile (resuelve type cast error)
      final response = await _api.uploadPDF(platformFile);

      // Progreso real: Si quieres, agrega onSendProgress en ApiService
      // Por ahora, simulado (opcional: remueve si no lo necesitas)
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() => _progress = i / 100);
        }
      }

      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0.0;
        });

        // Verificar y llamar callback con ID (asumiendo response['id'])
        if (response.containsKey('id') && response['id'] != null) {
          widget.onSuccess(response['id'] as String);
          _showSuccess('PDF subido: ${platformFile.name} (ID: ${response['id']})');
        } else {
          _showError('Respuesta inesperada del servidor (sin ID). Verifica logs.');
          print('Respuesta completa: $response'); // Para debug
        }
      }
    } on DioException catch (e) {
      print('Dio error en upload: Status ${e.response?.statusCode}, Data ${e.response?.data}'); // Logs
      setState(() {
        _uploading = false;
        _progress = 0.0;
      });

      String message;
      switch (e.response?.statusCode) {
        case 400:
          message = 'Error 400: No se recibió el archivo. Verifica conexión o backend.';
        case 500:
          message = 'Error interno del servidor. Intenta de nuevo.';
        default:
          message = 'Error de red: ${e.message ?? 'Desconocido'}';
      }
      _showError(message);
    } catch (e) {
      print('Error general en upload: $e'); // Logs
      setState(() {
        _uploading = false;
        _progress = 0.0;
      });
      _showError('Error al subir: $e');
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
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _uploading ? Icons.cloud_upload : Icons.picture_as_pdf,
                  size: 40,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                _uploading ? 'Subiendo PDF...' : 'Selecciona un PDF',
                style: const TextStyle(
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
                    LinearProgressIndicator(value: _progress), // Cambié a Linear para mejor UX
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
                  label: const Text('Subir PDF'),
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
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tamaño máximo: 10MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900]!, // Fix: Usa [900]! para const safety
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
