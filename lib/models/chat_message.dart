/// Data models for the chat app.

import 'dart:convert';
import 'dart:typed_data';

/// Types of attachments a user can upload.
enum AttachmentType {
  image,
  pdf,
  text,
  other,
}

/// An attachment (image, PDF, file) on a user message.
class Attachment {
  final String id;
  final String fileName;
  final AttachmentType type;
  final int sizeBytes;
  final String? base64Data; // base64-encoded file content for API calls
  final String? mimeType;
  final String? localPath; // local file path (for display)

  Attachment({
    required this.id,
    required this.fileName,
    required this.type,
    required this.sizeBytes,
    this.base64Data,
    this.mimeType,
    this.localPath,
  });

  AttachmentType get typeEnum => type;

  /// Human-readable file size.
  String get fileSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'type': type.name,
      'sizeBytes': sizeBytes,
      'base64Data': base64Data,
      'mimeType': mimeType,
      'localPath': localPath,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      type: AttachmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AttachmentType.other,
      ),
      sizeBytes: map['sizeBytes'] as int,
      base64Data: map['base64Data'] as String?,
      mimeType: map['mimeType'] as String?,
      localPath: map['localPath'] as String?,
    );
  }

  static Future<Attachment> fromBytes({
    required String fileName,
    required Uint8List bytes,
    required String? mimeType,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    AttachmentType type;
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext)) {
      type = AttachmentType.image;
    } else if (ext == 'pdf') {
      type = AttachmentType.pdf;
    } else if (['txt', 'md', 'csv', 'json', 'dart', 'py', 'js', 'ts'].contains(ext)) {
      type = AttachmentType.text;
    } else {
      type = AttachmentType.other;
    }

    return Attachment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      type: type,
      sizeBytes: bytes.length,
      base64Data: base64Encode(bytes),
      mimeType: mimeType,
    );
  }
}

/// A single chat message within a conversation.
class ChatMessage {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final List<Attachment> attachments;
  final DateTime createdAt;
  final bool isError;
  final bool isStreaming;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.attachments = const [],
    required this.createdAt,
    this.isError = false,
    this.isStreaming = false,
  });

  bool get isUser => role == 'user';
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasImages => attachments.any((a) => a.type == AttachmentType.image);

  ChatMessage copyWith({
    String? content,
    List<Attachment>? attachments,
    bool? isError,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      isError: isError ?? this.isError,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'role': role,
      'content': content,
      'attachments': jsonEncode(attachments.map((a) => a.toMap()).toList()),
      'createdAt': createdAt.toIso8601String(),
      'isError': isError,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversationId'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      attachments: (jsonDecode(map['attachments'] as String) as List)
          .map((e) => Attachment.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      isError: (map['isError'] as int?) == 1,
    );
  }

  /// Convert to the JSON format expected by the Sarvam chat API.
  Map<String, dynamic> toApiJson() {
    // If the message has image attachments, use the multimodal content format.
    if (hasImages && role == 'user') {
      final contentParts = <Map<String, dynamic>>[];
      for (final att in attachments.where((a) => a.type == AttachmentType.image)) {
        if (att.base64Data != null) {
          contentParts.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:${att.mimeType ?? 'image/jpeg'};base64,${att.base64Data}',
            },
          });
        }
      }
      if (contentParts.isNotEmpty) {
        contentParts.insert(0, {'type': 'text', 'text': content});
        return {'role': role, 'content': contentParts};
      }
    }
    return {'role': role, 'content': content};
  }
}

/// A conversation (chat thread) containing multiple messages.
class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  String? systemPrompt;
  int messageCount;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.systemPrompt,
    this.messageCount = 0,
  });

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    String? systemPrompt,
    int? messageCount,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'systemPrompt': systemPrompt,
      'messageCount': messageCount,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      systemPrompt: map['systemPrompt'] as String?,
      messageCount: (map['messageCount'] as num?)?.toInt() ?? 0,
    );
  }
}
