import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../models/document.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';
  final Dio _dio = Dio();

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(minutes: 5);

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      error: true,
    ));
  }

  // uploadPDF sin cambios (ya funciona)
  Future<Map<String, dynamic>> uploadPDF(PlatformFile platformFile) async {
    try {
      print('═══════════════════════════════════════');
      print('🚀 UPLOAD PDF - VERSIÓN CORREGIDA (CROSS-PLATFORM)');
      print('═══════════════════════════════════════');
      print('📁 Archivo: ${platformFile.path ?? 'N/A (web)'}');
      print('📄 Nombre: ${platformFile.name}');
      print('🖥️ Plataforma: ${kIsWeb ? "Web" : Platform.operatingSystem}');

      if (platformFile.bytes == null && (platformFile.path == null || platformFile.path!.isEmpty)) {
        throw Exception('No se pudo leer el archivo');
      }

      final size = platformFile.size;
      print('📊 Tamaño: $size bytes (${(size / 1024).toStringAsFixed(2)} KB)');

      if (size == 0) {
        throw Exception('El archivo está vacío');
      }

      MultipartFile multipartFile;
      final fileName = platformFile.name;
      final contentType = MediaType('application', 'pdf');

      if (kIsWeb) {
        // Web: siempre fromBytes (path no disponible)
        if (platformFile.bytes == null) {
          throw Exception('Bytes no disponibles en web');
        }
        print('🌐 Modo web: usando fromBytes');
        multipartFile = MultipartFile.fromBytes(
          platformFile.bytes!,
          filename: fileName,
          contentType: contentType,
        );
      } else if (platformFile.path != null) {
        // Desktop/Mobile: prioriza fromFile (más eficiente, envía como stream)
        print('💻 Modo desktop/mobile: usando fromFile (path: ${platformFile.path})');
        final file = File(platformFile.path!);
        if (!await file.exists()) {
          throw Exception('El archivo no existe: ${platformFile.path}');
        }
        multipartFile = await MultipartFile.fromFile(
          platformFile.path!,
          filename: fileName,
          contentType: contentType,
        );
      } else {
        // Fallback: fromBytes si path no hay
        if (platformFile.bytes == null) {
          throw Exception('Ni path ni bytes disponibles');
        }
        print('🔄 Fallback: usando fromBytes');
        multipartFile = MultipartFile.fromBytes(
          platformFile.bytes!,
          filename: fileName,
          contentType: contentType,
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      print('📦 FormData creado correctamente (clave: file)');
      print('🌐 Enviando a: $baseUrl/api/process');

      final response = await _dio.post(
        '$baseUrl/api/process',
        data: formData,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(minutes: 5),
          // Opcional: Para progreso real en PDFUploader
          // onSendProgress: (sent, total) => print('Progress: ${(sent / total * 100).toStringAsFixed(0)}%'),
        ),
      );

      print('═══════════════════════════════════════');
      print('✅ RESPUESTA DEL SERVIDOR');
      print('═══════════════════════════════════════');
      print('Status: ${response.statusCode}');
      print('Data: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }

    } on DioException catch (e) {
      print('═══════════════════════════════════════');
      print('❌ ERROR DIO');
      print('═══════════════════════════════════════');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      print('Headers: ${e.response?.headers}');
      throw Exception('Error ${e.response?.statusCode ?? 0}: ${e.response?.data ?? e.message}');
    } catch (e) {
      print('❌ Error general: $e');
      rethrow;
    }
  }

  // getDocument corregido (incluye images por default)
  Future<Document> getDocument(String id, {bool includeImages = true}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/process/$id',
        queryParameters: {'include_images': includeImages.toString()},
      );
      if (response.statusCode == 200) {
        return Document.fromJson(response.data);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      print('Error fetching document: $e');
      rethrow;
    }
  }

  // translateDocument sin cambios
  Future<Document> translateDocument(String id, String targetLang, {String sourceLang = 'auto'}) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/process/$id/translate',
        data: {'target_lang': targetLang, 'source_lang': sourceLang},
      );
      if (response.statusCode == 200) {
        return Document.fromJson(response.data);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      print('Error translating document: $e');
      rethrow;
    }
  }

  // getImage corregido para ImageData
  Future<ImageData> getImage(String imageId) async {
    try {
      final response = await _dio.get('$baseUrl/api/images/$imageId');  // Asume endpoint retorna JSON ImageData
      return ImageData.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Error ${e.response!.statusCode}: ${e.response!.data}');
      } else {
        throw Exception('Error de conexión: ${e.message}');
      }
    }
  }

  // deleteDocument sin cambios


  Future<Document> getDocumentTranslated(String id, String targetLang, {String sourceLang = 'auto'}) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/process/$id/translate',
        data: {'target_lang': targetLang, 'source_lang': sourceLang},
      );
      if (response.statusCode == 200) {
        return Document.fromJson(response.data);  // Asume retorna Document traducido
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } catch (e) {
      print('Error translating document: $e');
      rethrow;
    }
  }

// Opcional: Si image_ids son IDs, agrega endpoint para imágenes (ej. base64)
  Future<String> getImageBase64(String imageId) async {
    try {
      final response = await _dio.get('$baseUrl/api/image/$imageId');  // Asume endpoint retorna base64
      return response.data['base64'];
    } catch (e) {
      print('Error fetching image: $e');
      rethrow;
    }
  }

  // Eliminar documento (sin cambios)
  Future<void> deleteDocument(String id) async {
    try {
      await _dio.delete('$baseUrl/api/process/$id');
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception('Error ${e.response!.statusCode}: ${e.response!.data}');
      } else {
        throw Exception('Error de conexión: ${e.message}');
      }
    }
  }
}


