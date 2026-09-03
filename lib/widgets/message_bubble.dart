/// Message bubble widget — renders a single chat message.
///
/// Shows:
/// - User messages on the right (primary color)
/// - Assistant messages on the left (surface container)
/// - Image attachments inline
/// - Markdown rendering for AI responses
/// - Error state for failed messages
/// - Typing indicator for streaming messages

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRegenerate;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? cs.primaryContainer
              : message.isError
                  ? cs.errorContainer
                  : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image attachments.
            if (message.hasImages) ...[
              ...message.attachments
                  .where((a) => a.type == AttachmentType.image && a.base64Data != null)
                  .map((a) => _buildImage(a, cs)),
              const SizedBox(height: 8),
            ],

            // Non-image attachments (file chips).
            if (message.hasAttachments &&
                message.attachments.any((a) => a.type != AttachmentType.image)) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.attachments
                    .where((a) => a.type != AttachmentType.image)
                    .map((a) => _buildFileChip(a, cs))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Message content or typing indicator.
            if (message.isStreaming && message.content.isEmpty)
              const TypingIndicator()
            else if (message.content.isNotEmpty)
              MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser
                        ? cs.onPrimaryContainer
                        : message.isError
                            ? cs.onErrorContainer
                            : cs.onSurface,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  code: TextStyle(
                    backgroundColor: (isUser ? cs.primary : cs.surface).withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: cs.outline, width: 3),
                    ),
                  ),
                ),
              ),

            // Error icon.
            if (message.isError) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                  const SizedBox(width: 4),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // Timestamp + regenerate.
            if (!message.isStreaming) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: (isUser ? cs.onPrimaryContainer : cs.onSurfaceVariant)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  if (!isUser && onRegenerate != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onRegenerate,
                      child: Icon(
                        Icons.refresh,
                        size: 14,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImage(att, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Image.memory(
            base64Decode(att.base64Data!),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              height: 60,
              width: 60,
              color: cs.surfaceContainerHighest,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileChip(att, ColorScheme cs) {
    final icon = switch (att.type) {
      AttachmentType.pdf => Icons.picture_as_pdf,
      AttachmentType.text => Icons.description,
      AttachmentType.other => Icons.insert_drive_file,
      AttachmentType.image => Icons.image,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            att.fileName,
            style: TextStyle(fontSize: 12, color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Animated typing indicator (three bouncing dots).
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = (_controller.value + index * 0.2) % 1.0;
            final scale = 0.5 + 0.5 * (1 - (2 * offset - 1).abs());
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
