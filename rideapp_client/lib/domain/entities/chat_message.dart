class ChatMessage {
  final String id;
  final String tripId;
  final String senderId;
  final String senderRole; // 'passenger' or 'driver'
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tripId': tripId,
    'senderId': senderId,
    'senderRole': senderRole,
    'text': text,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    tripId: json['tripId'] ?? '',
    senderId: json['senderId'] ?? '',
    senderRole: json['senderRole'] ?? '',
    text: json['text'] ?? '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
  );
}
