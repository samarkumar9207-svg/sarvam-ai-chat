/// Chat input bar with attachment button, text field, and send button.
///
/// Also shows pending attachment chips above the text field.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController? controller;

  const ChatInputBar({super.key, this.controller});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && !context.read<ChatProvider>().hasPendingAttachments) return;
    context.read<ChatProvider>().sendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pending attachment chips.
              if (provider.hasPendingAttachments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAttachmentChips(provider, colorScheme),
                ),

              // Input row.
              Row(
                endAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment menu button.
                  MenuAnchor(
                    builder: (context, controller, child) {
                      return IconButton.filledTonal(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: const Icon(Icons.add),
                        tooltip: 'Attach',
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.photo_outlined),
                        child: const Text('Gallery Image'),
                        onPressed: () => provider.pickImage(),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.camera_alt_outlined),
                        child: const Text('Take Photo'),
                        onPressed: () => provider.takePhoto(),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.attach_file),
                        child: const Text('File (PDF, Text...)'),
                        onPressed: () => provider.pickFile(),
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // Text field.
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      enabled: !provider.isSending,
                      decoration: InputDecoration(
                        hintText: provider.isSending
                            ? 'AI is thinking...'
                            : 'Ask anything...',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        suffixIcon: provider.isSending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton.filled(
                      onPressed: (provider.isSending ||
                              (!_hasText && !provider.hasPendingAttachments))
                          ? null
                          : _send,
                      icon: const Icon(Icons.arrow_upward),
                      iconSize: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentChips(ChatProvider provider, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: provider.pendingAttachments.map((att) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: _buildAttachmentAvatar(att, colorScheme),
              label: Text(
                att.fileName.length > 20
                    ? '${att.fileName.substring(0, 17)}...'
                    : att.fileName,
                style: TextStyle(fontSize: 12),
              ),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => provider.removeAttachment(att.id),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttachmentAvatar(Attachment att, ColorScheme cs) {
    if (att.type == AttachmentType.image && att.base64Data != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          base64Decode(att.base64Data!),
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(att, cs),
        ),
      );
    }
    return _defaultAvatar(att, cs);
  }

  Widget _defaultAvatar(Attachment att, ColorScheme cs) {
    final icon = switch (att.type) {
      AttachmentType.image => Icons.image,
      AttachmentType.pdf => Icons.picture_as_pdf,
      AttachmentType.text => Icons.description,
      AttachmentType.other => Icons.insert_drive_file,
    };
    return Icon(icon, size: 18, color: cs.primary);
  }
}
