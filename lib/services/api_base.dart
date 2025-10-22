// dart:io only for non-web; conditional usage below
import 'dart:io' show Platform;  // Solo si !kIsWeb; wrap in if (!kIsWeb)
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';  // Para Providers
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custom exception para auth/PDF errors (con statusCode para specific handling)
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthException: $message ${statusCode != null ? '(code: $statusCode)' : ''}';
}

class ApiBase {
  // Getters para Base URLs (runtime: web/emulator/desktop/device)
  static String get _hostUrl {
    if (kIsWeb) return 'http://localhost';  // Web: localhost ok
    // Non-web: Use Platform (safe; import dart:io only runs here)
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2';  // Android emulator
    if (!kIsWeb && Platform.isIOS) return 'http://localhost';  // iOS simulator; physical: ajusta IP manual
    return 'http://localhost';  // Desktop (Linux/Mac/Windows)
  }
  static String get _authBaseUrl => '$_hostUrl:9001';  // Go auth backend
  static String get _documentBaseUrl => '$_hostUrl:8080/api';  // Java documents backend

  static Dio? _authDio;
  static Dio? _documentDio;
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static bool _useSecure = true;  // Flag para fallback a prefs si secure falla (e.g., web)

  // Provider para Dio Auth (usa getAuthDio(); para login/register/validate en 9001)
  static final dioProvider = Provider<Dio>((ref) => getAuthDio());

  // Provider para Dio Documents (usa getDocumentDio(); para /documents en 8080)
  static final documentDioProvider = Provider<Dio>((ref) => getDocumentDio());

  // Auth Dio (simple: logs, no token req para login; agrega si presente para validate)
  static Dio getAuthDio() {
    _authDio ??= Dio(BaseOptions(
      baseUrl: _authBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _setupLogInterceptor(_authDio!);  // Logs en debug ( ! safe post-??= )
    _setupAuthInterceptor(_authDio!);  // Opcional: Auto-add token si existe
    return _authDio!;
  }

  // Document Dio con full JWT interceptor (para Java calls protegidos)
  static Dio getDocumentDio() {
    _documentDio ??= Dio(BaseOptions(
      baseUrl: _documentBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),  // Largo para PDF uploads
      headers: {'Content-Type': 'application/json'},
    ));
    _setupDocumentInterceptors(_documentDio!);  // ! safe post-??=
    return _documentDio!;
  }

  // Setup auth interceptor (simple: auto-add token si stored, para /validate/refresh)
  static void _setupAuthInterceptor(Dio dio) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          if (kDebugMode) debugPrint('🔑 Auth token added for: ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final statusCode = error.response?.statusCode;
        if (kDebugMode) debugPrint('❌ Auth Dio error: ${error.message} (code: $statusCode)');
        if (statusCode == 401) {
          // Clear auth on 401 (no refresh aquí; maneja en AuthNotifier)
          clearAuth().then((_) => debugPrint('🚫 Auth cleared on 401'));
        }
        // Reject con explicit DioException (no spread; copy fields)
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            message: error.message ?? 'Unknown auth error',
            error: AuthException(
              statusCode == 404 ? 'Servidor auth no encontrado (puerto 9001)' : 'Error auth: ${error.message}',
              statusCode: statusCode,
            ),
          ),
        );
      },
    ));
  }

  // Setup document interceptors: Token auto, 401 clear + error handling
  static void _setupDocumentInterceptors(Dio dio) {
    if (kDebugMode) _setupLogInterceptor(dio);  // Logs solo en debug

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          if (kDebugMode) debugPrint('🔑 Document token added: ${options.path}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) debugPrint('✅ Document response: ${response.statusCode} ${response.requestOptions.uri.path}');
        handler.next(response);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        final response = error.response;
        final statusCode = response?.statusCode;
        if (kDebugMode) debugPrint('❌ Document Dio error: ${error.message} (code: $statusCode)');

        if (statusCode == 401) {
          await clearAuth();  // Clear token on unauthorized
          debugPrint('🚫 401 in documents: Session cleared');
          // Opcional: Auto-refresh? (Requiere ref a AuthNotifier; complejiza statics)
          // Si quieres: await ApiBase.refreshToken(); pero maneja en service
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              type: error.type,
              message: error.message ?? 'Unauthorized',
              error: AuthException('Sesión expirada en documentos.', statusCode: 401),
            ),
          );
        } else if (statusCode == 404) {
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              type: error.type,
              message: error.message ?? 'Not found',
              error: AuthException('Endpoint documents no encontrado (puerto 8080).', statusCode: 404),
            ),
          );
        } else if (statusCode == 500) {
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: response,
              type: error.type,
              message: error.message ?? 'Server error',
              error: AuthException('Error en servidor Java. Intenta más tarde.', statusCode: 500),
            ),
          );
        }
        handler.reject(error);  // Otros errors: Reject original (no next)
      },
    ));
  }

  // Log interceptor (solo debug, request/response bodies)
  static void _setupLogInterceptor(Dio dio) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      requestHeader: false,  // Opcional para menos logs
      responseHeader: false,
      logPrint: (obj) => debugPrint('[Dio] $obj'),  // Custom print
    ));
  }

  // Storage helpers con fallback secure → prefs (públicos para services)
  static Future<String?> getToken() async {
    if (_useSecure) {
      try {
        final token = await _storage.read(key: 'auth_token');
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        if (kDebugMode) debugPrint('Secure read fail (token): $e. Switching to fallback.');
        _useSecure = false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String?> getUserId() async {
    if (_useSecure) {
      try {
        final userId = await _storage.read(key: 'user_id');
        if (userId != null && userId.isNotEmpty) return userId;
      } catch (e) {
        if (kDebugMode) debugPrint('Secure read fail (user_id): $e. Switching to fallback.');
        _useSecure = false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> getUsername() async {
    if (_useSecure) {
      try {
        final username = await _storage.read(key: 'username');
        if (username != null && username.isNotEmpty) return username;
      } catch (e) {
        if (kDebugMode) debugPrint('Secure read fail (username): $e. Switching to fallback.');
        _useSecure = false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  static Future<void> writeAuthData(String token, String userId, String username) async {
    if (_useSecure) {
      try {
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'user_id', value: userId);
        await _storage.write(key: 'username', value: username);
        if (kDebugMode) debugPrint('✅ Auth data written securely');
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('Secure write fail: $e. Switching to fallback.');
        _useSecure = false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_id', userId);
    await prefs.setString('username', username);
    if (kDebugMode) debugPrint('📝 Auth data written to prefs (fallback)');
  }

  static Future<bool> isTokenSaved() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearAuth() async {
    if (_useSecure) {
      try {
        await _storage.delete(key: 'auth_token');
        await _storage.delete(key: 'user_id');
        await _storage.delete(key: 'username');
        if (kDebugMode) debugPrint('🗑️ Auth data cleared securely');
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('Secure clear fail: $e. Switching to fallback.');
        _useSecure = false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    if (kDebugMode) debugPrint('🗑️ Auth data cleared from prefs (fallback)');
  }

  // Opcional: Refresh helper (llama /auth/refresh; usa en AuthNotifier si needed)
  static Future<String?> refreshToken(String oldToken) async {
    try {
      final dio = getAuthDio();
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'token': oldToken},
        options: Options(headers: {'Authorization': 'Bearer $oldToken'}),
      );
      if (response.statusCode == 200) {
        final newToken = response.data?['token'] as String?;
        if (newToken != null) {
          // Get current userId/username para rewrite
          final userId = await getUserId();
          final username = await getUsername();
          await writeAuthData(newToken, userId ?? '', username ?? '');
          if (kDebugMode) debugPrint('🔄 Token refreshed successfully');
        }
        return newToken;
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('❌ Refresh failed: ${e.message}');
      await clearAuth();
      throw AuthException('No se pudo renovar token: ${e.message}', statusCode: e.response?.statusCode);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Refresh error: $e');
      throw AuthException('Error en refresh: $e');
    }
  }
}
