class EventMessage {
  final String id;
  final String eventId;
  final String userId;
  String content;
  final DateTime createdAt;
  DateTime updatedAt;
  String? senderName;
  String? senderAvatarUrl;

  EventMessage({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  factory EventMessage.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return EventMessage(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      senderName: profile != null
          ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim()
          : null,
      senderAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
