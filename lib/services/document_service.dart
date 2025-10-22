import 'dart:io' show Platform, File;
import 'dart:typed_data';  // Uint8List para PDF
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'api_base.dart';  // Dio, storage, AuthException
import '../models/document.dart';
import 'api_base.dart' show ApiBase, AuthException;  // Asume Document e ImageData (ajusta si needed)

class DocumentService {
  // Upload PDF (multipart a Java)
  static Future<Map<String, dynamic>> uploadPdf(
      PlatformFile platformFile, {
        Function(int, int)? onSendProgress,
        String? language,  // Opcional para Java processing
      }) async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🚀 UPLOAD PDF A JAVA - CON AUTH Y PROGRESO');
      debugPrint('═══════════════════════════════════════');
      debugPrint('📁 Archivo: ${platformFile.path ?? 'N/A (web)'}');
      debugPrint('📄 Nombre: ${platformFile.name}');

      if (platformFile.bytes == null && (platformFile.path == null || platformFile.path!.isEmpty)) {
        throw Exception('No se pudo leer el archivo');
      }

      final size = platformFile.size;
      if (size == 0 || size > 50 * 1024 * 1024) {  // 50MB max
        throw Exception('Archivo inválido o demasiado grande');
      }

      MultipartFile multipartFile;
      final fileName = platformFile.name;
      final contentType = MediaType('application', 'pdf');

      if (kIsWeb) {
        if (platformFile.bytes == null) throw Exception('Bytes no disponibles en web');
        multipartFile = MultipartFile.fromBytes(
          platformFile.bytes!,
          filename: fileName,
          contentType: contentType,
        );
      } else if (platformFile.path != null) {
        final file = File(platformFile.path!);
        if (!await file.exists()) throw Exception('Archivo no existe');
        multipartFile = await MultipartFile.fromFile(
          platformFile.path!,
          filename: fileName,
          contentType: contentType,
        );
      } else {
        multipartFile = MultipartFile.fromBytes(
          platformFile.bytes!,
          filename: fileName,
          contentType: contentType,
        );
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
        if (language != null) 'language': language,
      });

      final dio = ApiBase.getDocumentDio();  // Token auto
      final response = await dio.post(
        '/documents',
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(minutes: 5),
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      debugPrint('✅ Upload Java: ${response.statusCode}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data as Map<String, dynamic>;  // {'id': UUID, 'filename': '...'}
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout) {
        debugPrint('❌ Timeout en upload');
      }
      debugPrint('❌ Upload Dio: ${e.response?.statusCode}, ${e.response?.data}');
      String msg = e.message ?? 'Upload error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('❌ Upload general: $e');
      rethrow;
    }
  }

  // List Documents (para dashboard: paginación + búsqueda)
  static Future<Map<String, dynamic>> listDocuments({
    int page = 0,
    int size = 10,
    String? query,
  }) async {
    try {
      final dio = ApiBase.getDocumentDio();
      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
        if (query != null && query.isNotEmpty) 'q': query,
      };
      final response = await dio.get(
        '/documents',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;  // {'content': [docs], 'totalElements': N, ...}
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      debugPrint('❌ List Docs: ${e.response?.data ?? e.message}');
      String msg = e.message ?? 'List error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  // Get Document (detalles con mode)
  static Future<Document?> getDocument(
      String id, {
        bool includeImages = true,
        String mode = 'paged',  // paged/continuous/visualization
      }) async {
    try {
      final dio = ApiBase.getDocumentDio();
      final queryParams = <String, dynamic>{
        'include_images': includeImages.toString(),
        'mode': mode,
      };
      final response = await dio.get(
        '/documents/$id',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null) {
          debugPrint('✅ Doc loaded: ID $id, mode: $mode');
          return Document.fromJson(data);  // Asume model con pages/tables/images
        }
        return null;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      if (e.type == DioExceptionType.connectionTimeout) {
        debugPrint('❌ Timeout en getDocument $id');
      }
      if (e.response?.statusCode == 404) {
        return null;  // No throw para graceful handling
      }
      debugPrint('❌ GetDocument $id: ${e.response?.statusCode ?? 'No response'} - ${e.message}');
      String msg = e.message ?? 'Fetch error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? data['error'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('❌ General getDocument: $e');
      rethrow;
    }
  }

  // Translate Document (opcional; si Java soporta, o external)
  static Future<Document> translateDocument(
      String id,
      String targetLang, {
        String sourceLang = 'auto',
      }) async {
    try {
      final dio = ApiBase.getDocumentDio();
      final response = await dio.post(
        '/documents/$id/translate',
        data: {'target_lang': targetLang, 'source_lang': sourceLang},
        options: Options(contentType: 'application/json'),
      );
      if (response.statusCode == 200) {
        return Document.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.data}');
      }
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      debugPrint('❌ Translate: ${e.response?.data ?? e.message}');
      String msg = e.message ?? 'Translate error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  // Get PDF Bytes
  static Future<Uint8List> getPdf(String documentId) async {
    try {
      final dio = ApiBase.getDocumentDio();
      final response = await dio.get(
        '/documents/$documentId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        return response.data as Uint8List;
      } else {
        throw Exception('Error ${response.statusCode}: No se pudo obtener PDF');
      }
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      String msg = e.message ?? 'PDF error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('❌ PDF fetch: $e');
      rethrow;
    }
  }

  // Get Image (asume /documents/{docId}/images/{imageId})
  static Future<Map<String, dynamic>> getImage(String docId, String imageId) async {
    try {
      final dio = ApiBase.getDocumentDio();
      final response = await dio.get('/documents/$docId/images/$imageId');
      return response.data as Map<String, dynamic>;  // O ImageData.fromJson si model
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      String msg = e.message ?? 'Image error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('❌ Image fetch: $e');
      rethrow;
    }
  }

  // Get Image Base64
  static Future<String> getImageBase64(String docId, String imageId) async {
    try {
      final dio = ApiBase.getDocumentDio();
      final response = await dio.get('/documents/$docId/images/$imageId/base64');
      return response.data['base64'] as String;
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      String msg = e.message ?? 'Base64 error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  // Delete Document
  static Future<void> deleteDocument(String id) async {
    try {
      final dio = ApiBase.getDocumentDio();
      await dio.delete('/documents/$id');
      debugPrint('✅ Deleted: $id');
    } on DioException catch (e) {
      if (e.error is AuthException) rethrow;
      String msg = e.message ?? 'Delete error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['message'] ?? msg) : data.toString();
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('❌ Delete: $e');
      rethrow;
    }
  }
}
