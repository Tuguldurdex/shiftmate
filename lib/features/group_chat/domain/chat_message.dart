enum MessageType { text, mention, ai }

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String messageText;
  final DateTime timestamp;
  final MessageType type;
  final List<String> mentionedUserIds;
  final Map<String, bool> readBy;
  final String? aiModel;
  final int? responseTimeMs;
  final int? tokenCount;
  final bool? feedbackPositive;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.messageText,
    required this.timestamp,
    this.type = MessageType.text,
    this.mentionedUserIds = const [],
    this.readBy = const {},
    this.aiModel,
    this.responseTimeMs,
    this.tokenCount,
    this.feedbackPositive,
  });

  String get senderInitials {
    final parts = senderName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return senderName.isNotEmpty ? senderName[0].toUpperCase() : '?';
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  bool get isAiMessage => type == MessageType.ai;

  bool hasBeenReadBy(String userId) => readBy[userId] == true;

  int get readCount => readBy.values.where((v) => v).length;

  ChatMessage copyWith({
    String? messageText,
    MessageType? type,
    List<String>? mentionedUserIds,
    Map<String, bool>? readBy,
    String? aiModel,
    int? responseTimeMs,
    int? tokenCount,
    bool? feedbackPositive,
  }) {
    return ChatMessage(
      id: id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      messageText: messageText ?? this.messageText,
      timestamp: timestamp,
      type: type ?? this.type,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      readBy: readBy ?? this.readBy,
      aiModel: aiModel ?? this.aiModel,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      tokenCount: tokenCount ?? this.tokenCount,
      feedbackPositive: feedbackPositive ?? this.feedbackPositive,
    );
  }
}
