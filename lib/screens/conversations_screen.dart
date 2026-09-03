/// Conversations screen — shows chat history.
///
/// Lists all saved conversations with title, last updated time, and
/// message count. Supports tap to open, rename, and delete.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat History')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.conversations.isEmpty
              ? _buildEmpty(cs)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: provider.conversations.length,
                  itemBuilder: (context, index) {
                    final conv = provider.conversations[index];
                    final isActive = provider.activeConversation?.id == conv.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? cs.primaryContainer
                            : cs.surfaceContainerHigh,
                        child: Icon(
                          Icons.chat_bubble_outline,
                          color: isActive ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        conv.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${conv.messageCount} messages · ${_formatDate(conv.updatedAt)}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'rename':
                              _showRenameDialog(provider, conv.id, conv.title);
                              break;
                            case 'delete':
                              _showDeleteConfirm(provider, conv.id, conv.title);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () {
                        provider.selectConversation(conv);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          provider.startNewConversation();
          Navigator.pop(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat to see it here.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return DateFormat('h:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  void _showRenameDialog(ChatProvider provider, String id, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.renameConversation(id, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(ChatProvider provider, String id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              provider.deleteConversation(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
