import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'api_base.dart';  // Utilidades y AuthException

class AuthService {
  // Login (retorna data para AuthProvider; no save aquí)
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final dio = ApiBase.getAuthDio();
      final response = await dio.post(
        '/api/auth/login',  // Ajusta si tu Go usa /auth/login sin /api
        data: {'username': username, 'password': password},
        options: Options(contentType: 'application/json'),
      );
      if (response.statusCode == 200) {
        debugPrint('✅ Login HTTP: 200');
        return response.data as Map<String, dynamic>;  // {'token': '...', 'user_id': 1}
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Login falló: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ Login Dio error: ${e.response?.data ?? e.message}');
      String msg = e.message ?? 'Login error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['error'] ?? data['message'] ?? 'Invalid credentials') : data.toString();
      }
      throw AuthException(msg);
    } catch (e) {
      debugPrint('❌ Login general: $e');
      rethrow;
    }
  }

  // Register (similar, solo user_id)
  static Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final dio = ApiBase.getAuthDio();
      final response = await dio.post(
        '/api/auth/register',  // Ajusta path si needed
        data: {'username': username, 'password': password},
        options: Options(contentType: 'application/json'),
      );
      if (response.statusCode == 201) {
        debugPrint('✅ Register HTTP: 201');
        return response.data as Map<String, dynamic>;  // {'user_id': 1, 'message': '...'}
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Register falló: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ Register Dio error: ${e.response?.data ?? e.message}');
      String msg = e.message ?? 'Register error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['error'] ?? 'User already exists') : data.toString();
      }
      throw AuthException(msg);
    } catch (e) {
      debugPrint('❌ Register general: $e');
      rethrow;
    }
  }

  // Validate Token (usa getToken de base)
  static Future<Map<String, dynamic>> validateToken() async {
    try {
      final token = await ApiBase.getToken();
      if (token == null || token.isEmpty) {
        throw AuthException('No token available');
      }

      final dio = ApiBase.getAuthDio();
      final response = await dio.get(
        '/api/auth/validate',  // Agrega este endpoint en Go si no existe
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['valid'] == true) {
          debugPrint('🔑 Validate success');
          return data;  // {'valid': true, 'user_id': 1, ...}
        }
      }
      await ApiBase.clearAuth();
      throw AuthException('Token inválido');
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await ApiBase.clearAuth();
        throw AuthException('Token expirado o inválido');
      } else if (e.response?.statusCode == 404) {
        debugPrint('⚠️ 404 validate: Configura /api/auth/validate en Go.');
        throw Exception('Validate endpoint no configurado');
      }
      String msg = e.message ?? 'Validation failed';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['error'] ?? msg) : data.toString();
      }
      throw AuthException(msg);
    } catch (e) {
      debugPrint('❌ Validate general: $e');
      rethrow;
    }
  }

  // Opcional: Refresh (implementa en Go /api/auth/refresh)
  static Future<Map<String, dynamic>> refreshToken(String oldToken) async {
    try {
      final dio = ApiBase.getAuthDio();
      final response = await dio.post(
        '/api/auth/refresh',
        data: {'token': oldToken},
        options: Options(contentType: 'application/json'),
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;  // {'token': newToken}
      } else {
        throw AuthException('Refresh failed');
      }
    } on DioException catch (e) {
      String msg = e.message ?? 'Refresh error';
      if (e.response?.data != null) {
        final data = e.response!.data;
        msg = data is Map ? (data['error'] ?? msg) : data.toString();
      }
      throw AuthException(msg);
    } catch (e) {
      rethrow;
    }
  }
}
