import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';  // Para Provider
import 'api_base.dart' as api_base;  // Dio + AuthException + storage (ajusta path si needed)

// Servicio Auth (API calls a Go backend; inyectable via Provider)
class AuthService {
  // Validate token (GET /auth/validate; retorna data si valid)
  Future<Map<String, dynamic>?> validateToken() async {
    try {
      final dio = api_base.ApiBase.getAuthDio();
      final response = await dio.get<Map<String, dynamic>>('/auth/validate');
      if (response.statusCode == 200) {
        if (kDebugMode) debugPrint('✅ Token valid: ${response.data}');  // {"valid":true, "user_id":1, "username":email}
        return response.data;
      }
      if (kDebugMode) debugPrint('ℹ️ Validate response: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      final msg = _getAuthErrorMessage(e);
      if (kDebugMode) debugPrint('❌ Validate error: $msg');
      if (e.response?.statusCode == 401) {
        await api_base.ApiBase.clearAuth();  // Clear invalid token
      }
      throw api_base.AuthException(msg, statusCode: e.response?.statusCode);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Unexpected validate error: $e');
      throw api_base.AuthException('Error de conexión en validación: $e');
    }
  }

  // Login (POST /auth/login; store data on success) (Fix: email vs username)
  Future<Map<String, dynamic>> login(String email, String password) async {  // Fix: Param email
    try {
      final dio = api_base.ApiBase.getAuthDio();
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},  // Fix: 'email' en JSON
      );
      if (response.statusCode == 200) {
        final data = response.data!;
        final token = data['token'] as String?;
        final userId = data['user_id']?.toString() ?? '';
        final savedUsername = data['username']?.toString() ?? email.trim();  // Fix: username = email de response
        if (token != null && token.isNotEmpty) {
          await api_base.ApiBase.writeAuthData(token, userId, savedUsername);
          if (kDebugMode) debugPrint('✅ Login success: $savedUsername');
          return data;
        }
        throw api_base.AuthException('Token no recibido del servidor');
      }
      if (kDebugMode) debugPrint('ℹ️ Login response: ${response.statusCode}');
      throw api_base.AuthException('Login falló: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = _getAuthErrorMessage(e);
      if (kDebugMode) debugPrint('❌ Login error: $msg');
      throw api_base.AuthException(msg, statusCode: e.response?.statusCode);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Unexpected login error: $e');
      throw api_base.AuthException('Error inesperado en login: $e');
    }
  }

  // Register (POST /auth/register; store + auto-login effect) (Fix: email vs username)
  Future<Map<String, dynamic>> register(String email, String password) async {  // Fix: Param email
    try {
      final dio = api_base.ApiBase.getAuthDio();
      final response = await dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'email': email.trim(), 'password': password},  // Fix: 'email' en JSON
      );
      if (response.statusCode == 201) {
        final data = response.data!;
        final token = data['token'] as String?;
        final userId = data['user_id']?.toString() ?? '';
        final savedUsername = data['username']?.toString() ?? email.trim();  // Fix: username = email
        if (token != null && token.isNotEmpty) {
          await api_base.ApiBase.writeAuthData(token, userId, savedUsername);
          if (kDebugMode) debugPrint('✅ Register success: $savedUsername');
          return data;
        }
        throw api_base.AuthException('Token no recibido del servidor');
      }
      if (kDebugMode) debugPrint('ℹ️ Register response: ${response.statusCode}');
      throw api_base.AuthException('Registro falló: ${response.statusCode}');
    } on DioException catch (e) {
      final msg = _getAuthErrorMessage(e);
      if (kDebugMode) debugPrint('❌ Register error: $msg');
      throw api_base.AuthException(msg, statusCode: e.response?.statusCode);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Unexpected register error: $e');
      throw api_base.AuthException('Error inesperado en registro: $e');
    }
  }

  // Refresh (POST /auth/refresh; usa ApiBase helper o directo)
  Future<String?> refreshToken(String oldToken) async {
    try {
      final newToken = await api_base.ApiBase.refreshToken(oldToken);
      if (newToken != null) {
        if (kDebugMode) debugPrint('🔄 Token refreshed');
        // Rewrite con stored userId/username (username = email)
        final userId = await api_base.ApiBase.getUserId();
        final username = await api_base.ApiBase.getUsername();
        await api_base.ApiBase.writeAuthData(newToken, userId ?? '', username ?? '');
      }
      return newToken;
    } on DioException catch (e) {
      final msg = _getAuthErrorMessage(e);
      if (kDebugMode) debugPrint('❌ Refresh Dio error: $msg');
      await api_base.ApiBase.clearAuth();
      throw api_base.AuthException(msg, statusCode: e.response?.statusCode);
    } on api_base.AuthException catch (e) {
      if (kDebugMode) debugPrint('❌ Refresh AuthException: ${e.message}');
      await api_base.ApiBase.clearAuth();
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Unexpected refresh error: $e');
      throw api_base.AuthException('Error en renovación: $e');
    }
  }

  // Storage helpers (wrap ApiBase para consistency; username = email)
  Future<String?> getStoredToken() async {
    final token = await api_base.ApiBase.getToken();
    if (kDebugMode && token == null) debugPrint('ℹ️ No stored token');
    return token;
  }

  Future<String?> getStoredUserId() async {
    return await api_base.ApiBase.getUserId();
  }

  Future<String?> getStoredUsername() async {  // Retorna email stored
    return await api_base.ApiBase.getUsername();
  }

  Future<bool> isTokenSaved() async {
    return await api_base.ApiBase.isTokenSaved();
  }

  Future<void> clearToken() async {
    await api_base.ApiBase.clearAuth();
    if (kDebugMode) debugPrint('🔓 All auth data cleared');
  }

  // Helper: Msg para Dio errors (specific por statusCode; match Go)
  String _getAuthErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    switch (code) {
      case 404:
        return 'Servidor no encontrado (verifica puerto 9001)';
      case 401:
        return 'Usuario o contraseña inválidos';  // Match Go 401
      case 409:
        return 'Usuario ya existe';  // Match Go conflict
      case 400:
        return 'Datos inválidos (password mínimo 6 caracteres)';  // Match Go binding/min len
      case 500:
        return 'Error en servidor auth. Intenta más tarde';  // Match Go
      default:
        return 'Error de red: ${e.message}';
    }
  }
}

// Provider para inyectar AuthService (usa ApiBase internamente)
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();  // No deps; ApiBase statics manejan Dio/storage
});
