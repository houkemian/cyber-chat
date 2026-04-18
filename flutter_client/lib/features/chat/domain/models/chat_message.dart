enum SystemKind { join, leave, generic, cfs }

class UiChatMessage {
  UiChatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.systemKind,
    this.sender,
    this.isHistory = false,
  });

  final String id;
  final String type;
  final String content;
  final String timestamp;
  final SystemKind? systemKind;
  final String? sender;
  final bool isHistory;
}
