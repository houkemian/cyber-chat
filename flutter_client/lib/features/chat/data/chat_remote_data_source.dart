import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';

class HistoryMessageDto {
  HistoryMessageDto({
    required this.type,
    required this.content,
    required this.timestamp,
    this.sender,
  });

  final String type;
  final String content;
  final String timestamp;
  final String? sender;

  factory HistoryMessageDto.fromJson(Map<String, dynamic> json) {
    return HistoryMessageDto(
      type: json['type'] as String? ?? 'chat',
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      sender: json['sender'] as String?,
    );
  }
}

class RoomMembersDto {
  RoomMembersDto({required this.members, required this.onlineCount});

  final List<String> members;
  final int onlineCount;

  factory RoomMembersDto.fromJson(Map<String, dynamic> json) {
    final raw = json['members'];
    final list = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    return RoomMembersDto(
      members: list,
      onlineCount: json['online_count'] as int? ?? list.length,
    );
  }
}

class AnnouncementItemDto {
  const AnnouncementItemDto({required this.id, required this.content});

  final String id;
  final String content;

  factory AnnouncementItemDto.fromJson(Map<String, dynamic> json) {
    return AnnouncementItemDto(
      id: json['id']?.toString() ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

class ChatRemoteDataSource {
  ChatRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<HistoryMessageDto>> fetchHistory(String roomId, {int limit = 200}) async {
    final uri = Uri.parse(ApiEndpoints.chatHistoryUrl(roomId, limit: limit));
    final response = await _client.get(uri).timeout(const Duration(milliseconds: 4000));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('history_http_${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => HistoryMessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoomMembersDto> fetchMembers(String roomId) async {
    final uri = Uri.parse(ApiEndpoints.roomMembersUrl(roomId));
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('members_http_${response.statusCode}');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return RoomMembersDto.fromJson(map);
  }

  Future<List<AnnouncementItemDto>> fetchAnnouncements() async {
    final uri = Uri.parse(ApiEndpoints.announcementsUrl());
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('announcements_http_${response.statusCode}');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>? ?? const <dynamic>[];
    return items.map((e) => AnnouncementItemDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  void dispose() {
    _client.close();
  }
}
