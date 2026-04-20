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

class ForgeIdentityPreview {
  ForgeIdentityPreview({
    required this.cyberName,
    this.remainingAttempts,
  });

  final String cyberName;
  final int? remainingAttempts;
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

  Future<ForgeIdentityPreview> forgeIdentityPreview({required String token}) async {
    final uri = Uri.parse(ApiEndpoints.forgeIdentityPreviewUrl);
    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final cyberName = map['cyber_name'] as String?;
      final dynamic remainingRaw = map['remaining_attempts'];
      final int? remaining = switch (remainingRaw) {
        int v => v,
        num v => v.toInt(),
        String v => int.tryParse(v),
        _ => null,
      };
      if (cyberName == null) {
        throw AuthRepositoryException('响应格式异常');
      }
      return ForgeIdentityPreview(cyberName: cyberName, remainingAttempts: remaining);
    }
    if (response.statusCode == 401) {
      throw AuthRepositoryException('未授权或令牌失效');
    }
    if (response.statusCode == 429) {
      throw AuthRepositoryException('昵称重构次数已耗尽');
    }
    final String detail = _extractDetail(response.body);
    throw AuthRepositoryException('forge_preview_failed: $detail', detail: response.body);
  }

  Future<AuthResult> saveForgedIdentity({
    required String token,
    required String cyberName,
  }) async {
    final uri = Uri.parse(ApiEndpoints.forgeIdentitySaveUrl);
    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{'cyber_name': cyberName.trim()}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = map['token'] as String?;
      final newCyberName = map['cyber_name'] as String?;
      if (newToken == null || newCyberName == null) {
        throw AuthRepositoryException('响应格式异常');
      }
      return AuthResult(token: newToken, cyberName: newCyberName);
    }
    if (response.statusCode == 401) {
      throw AuthRepositoryException('未授权或令牌失效');
    }
    throw AuthRepositoryException('forge_save_failed', detail: response.body);
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

  String _extractDetail(String body) {
    try {
      final dynamic data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail;
      }
    } catch (_) {
      // ignore parse failure and fallback to raw text
    }
    final trimmed = body.trim();
    return trimmed.isEmpty ? 'unknown_error' : trimmed;
  }
}
