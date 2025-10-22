import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_base.dart' as api_base;  // Fix: Usa ApiBase para token/refresh (no notifier)
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

// Dio global para app (usa ApiBase providers; interceptors auto-token y refresh)
final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio();  // O usa api_base.dioProvider/documentDioProvider si specific
  _setupDioInterceptors(dio, ref);  // Interceptors con token/refresh
  return dio;
});

// Setup interceptors para DioClient (add token, refresh on 401, log)
void _setupDioInterceptors(Dio dio, Ref ref) {
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint('[DioClient] $obj'),
    ));
  }

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Fix: Usa ApiBase.getToken() (no notifier.getToken())
      final token = await api_base.ApiBase.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        if (kDebugMode) debugPrint('🔑 DioClient token added: ${options.path}');
      }
      handler.next(options);
    },
    onError: (DioException error, ErrorInterceptorHandler handler) async {
      final response = error.response;
      final statusCode = response?.statusCode;
      if (kDebugMode) debugPrint('❌ DioClient error: ${error.message} (code: $statusCode)');

      if (statusCode == 401) {
        final token = await api_base.ApiBase.getToken();  // Get current token
        if (token != null) {
          try {
            // Fix: Usa ApiBase.refreshToken(token) (no notifier.refreshToken())
            final newToken = await api_base.ApiBase.refreshToken(token);
            if (newToken != null) {
              if (kDebugMode) debugPrint('🔄 DioClient token refreshed');
              // Retry request con new token
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                ),
              );
              return handler.resolve(retryResponse);
            }
          } catch (refreshError) {
            if (kDebugMode) debugPrint('❌ DioClient refresh failed: $refreshError');
            await api_base.ApiBase.clearAuth();  // Clear on fail
            // Opcional: notifier.logout() via ref si needed
          }
        }
        // Reject con AuthException
        return handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: response,
            type: error.type,
            message: error.message ?? 'Unauthorized',
            error: api_base.AuthException('Sesión expirada. Reinicia login.', statusCode: 401),
          ),
        );
      }
      handler.reject(error);  // Otros errors
    },
  ));
}

// Uso: En services/screens, ref.watch(dioClientProvider) para Dio con auth ready
