import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';

class AuthRepositoryException implements Exception {
  AuthRepositoryException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => 'AuthRepositoryException: $message';
}

class AuthResult {
  AuthResult({required this.token, required this.cyberName});

  final String token;
  final String cyberName;
}

class AuthRepository {
  AuthRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> sendKey(String phoneNumber) async {
    final uri = Uri.parse('${ApiEndpoints.authBase}/send-key');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{'phone_number': phoneNumber.trim()}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw AuthRepositoryException('信道被干扰，请稍后重试', detail: response.body);
  }

  /// 伪造新身份：服务端用 [generator.generate_cyber_name] 生成网名并更新档案，返回新 JWT。
  Future<AuthResult> forgeIdentity({required String token}) async {
    final uri = Uri.parse(ApiEndpoints.forgeIdentityUrl);
    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = map['token'] as String?;
      final cyberName = map['cyber_name'] as String?;
      if (newToken == null || cyberName == null) {
        throw AuthRepositoryException('响应格式异常');
      }
      return AuthResult(token: newToken, cyberName: cyberName);
    }
    if (response.statusCode == 401) {
      throw AuthRepositoryException('未授权或令牌失效');
    }
    throw AuthRepositoryException('forge_failed', detail: response.body);
  }

  Future<AuthResult> verify({
    required String phoneNumber,
    required String smsCode,
  }) async {
    final uri = Uri.parse('${ApiEndpoints.authBase}/verify');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'phone_number': phoneNumber.trim(),
        'sms_code': smsCode.trim(),
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final token = map['token'] as String?;
      final cyberName = map['cyber_name'] as String?;
      if (token == null || cyberName == null) {
        throw AuthRepositoryException('响应格式异常');
      }
      return AuthResult(token: token, cyberName: cyberName);
    }
    if (response.statusCode == 400) {
      try {
        final detail = jsonDecode(response.body);
        if (detail is Map<String, dynamic> && detail['detail'] == 'invalid_or_expired_code') {
          throw AuthRepositoryException('invalid_or_expired_code', detail: 'invalid_or_expired_code');
        }
      } catch (e) {
        if (e is AuthRepositoryException) rethrow;
      }
    }
    throw AuthRepositoryException('verify_failed', detail: response.body);
  }

  void dispose() {
    _client.close();
  }
}
